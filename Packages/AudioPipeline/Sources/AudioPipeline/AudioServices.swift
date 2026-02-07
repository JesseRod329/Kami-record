import AVFoundation
import CoreAgent
import Foundation

public enum AudioPipelineError: Error, Equatable {
    case timeout
    case maxRetriesExceeded
    case microphoneDenied
}

public enum MicrophonePermissionState: Sendable, Equatable {
    case authorized
    case denied
    case restricted
    case undetermined
}

public protocol MicrophonePermissionProviding: Sendable {
    func currentPermission() -> MicrophonePermissionState
    func requestPermission() async -> MicrophonePermissionState
}

public enum RecorderState: Sendable, Equatable {
    case idle
    case recording
    case saving
    case error
}

public struct RecordingArtifact: Sendable, Equatable {
    public let fileURL: URL
    public let duration: TimeInterval
    public let createdAt: Date

    public init(fileURL: URL, duration: TimeInterval, createdAt: Date) {
        self.fileURL = fileURL
        self.duration = duration
        self.createdAt = createdAt
    }
}

public protocol AudioRecorderService: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> RecordingArtifact
    func cancelRecording() async
    func latestRecording() async -> RecordingArtifact?
    func outputDirectory() async -> URL
    func setOutputDirectory(_ url: URL) async throws
}

public enum AudioRecorderError: Error, Equatable {
    case alreadyRecording
    case notRecording
    case failedToStart
    case failedToSave
    case invalidOutputDirectory
}

public actor PorcupineWakeWordService: WakeWordService {
    private let keyword: String
    private let debounceSeconds: TimeInterval
    private var isRunning = false
    private var lastDetection: Date?
    private let stream: AsyncStream<WakeWordEvent>
    private let continuation: AsyncStream<WakeWordEvent>.Continuation

    public init(keyword: String, debounceSeconds: TimeInterval = 0.8) {
        self.keyword = keyword
        self.debounceSeconds = debounceSeconds

        var localContinuation: AsyncStream<WakeWordEvent>.Continuation?
        self.stream = AsyncStream<WakeWordEvent> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation!
    }

    public func start() async throws {
        isRunning = true
    }

    public func stop() async {
        isRunning = false
    }

    public func events() async -> AsyncStream<WakeWordEvent> {
        stream
    }

    public func emitDetection(now: Date = Date()) {
        guard isRunning else {
            return
        }

        if let lastDetection, now.timeIntervalSince(lastDetection) < debounceSeconds {
            return
        }

        lastDetection = now
        continuation.yield(WakeWordEvent(keyword: keyword, detectedAt: now))
    }
}

public final class SystemMicrophonePermissionProvider: @unchecked Sendable, MicrophonePermissionProviding {
    public init() {}

    public func currentPermission() -> MicrophonePermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .undetermined
        @unknown default:
            .undetermined
        }
    }

    public func requestPermission() async -> MicrophonePermissionState {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted ? .authorized : .denied)
            }
        }
    }
}

public actor AudioStartupCoordinator {
    private let permissionProvider: MicrophonePermissionProviding

    public init(permissionProvider: MicrophonePermissionProviding) {
        self.permissionProvider = permissionProvider
    }

    public func prepareAudioInput() async throws {
        let current = permissionProvider.currentPermission()
        switch current {
        case .authorized:
            return
        case .undetermined:
            let requested = await permissionProvider.requestPermission()
            guard requested == .authorized else {
                throw AudioPipelineError.microphoneDenied
            }
        case .denied, .restricted:
            throw AudioPipelineError.microphoneDenied
        }
    }
}

protocol AudioRecordingSession: AnyObject {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }
    func prepare() -> Bool
    func start() -> Bool
    func stop()
}

final class AVAudioRecordingSession: AudioRecordingSession {
    private let recorder: AVAudioRecorder

    init(url: URL, settings: [String: Any]) throws {
        recorder = try AVAudioRecorder(url: url, settings: settings)
    }

    var isRecording: Bool { recorder.isRecording }
    var currentTime: TimeInterval { recorder.currentTime }

    func prepare() -> Bool {
        recorder.prepareToRecord()
    }

    func start() -> Bool {
        recorder.record()
    }

    func stop() {
        recorder.stop()
    }
}

typealias RecorderFactory = @Sendable (URL, [String: Any]) throws -> AudioRecordingSession

private let defaultRecorderSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44_100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderBitRateKey: 128_000,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]

public actor LocalAudioRecorderService: AudioRecorderService {
    private let permissionProvider: MicrophonePermissionProviding
    private var capturesDirectory: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let recorderFactory: RecorderFactory
    private let recordingSettings: [String: Any]

    private var activeRecorder: AudioRecordingSession?
    private var activeFileURL: URL?
    private var startedAt: Date?
    private var latestArtifact: RecordingArtifact?
    private var state: RecorderState = .idle

    public init(
        permissionProvider: MicrophonePermissionProviding = SystemMicrophonePermissionProvider(),
        outputDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.permissionProvider = permissionProvider
        self.capturesDirectory = outputDirectory ?? Self.defaultOutputDirectory(fileManager: fileManager)
        self.fileManager = fileManager
        self.now = { Date() }
        self.recorderFactory = { url, settings in
            try AVAudioRecordingSession(url: url, settings: settings)
        }
        self.recordingSettings = defaultRecorderSettings
    }

    init(
        permissionProvider: MicrophonePermissionProviding,
        capturesDirectory: URL,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date,
        recorderFactory: @escaping RecorderFactory,
        recordingSettings: [String: Any] = defaultRecorderSettings
    ) {
        self.permissionProvider = permissionProvider
        self.capturesDirectory = capturesDirectory
        self.fileManager = fileManager
        self.now = now
        self.recorderFactory = recorderFactory
        self.recordingSettings = recordingSettings
    }

    public func startRecording() async throws {
        guard state != .recording else {
            throw AudioRecorderError.alreadyRecording
        }

        try await ensureMicrophonePermission()
        try fileManager.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)

        let startDate = now()
        let fileURL = capturesDirectory
            .appendingPathComponent(Self.filename(for: startDate))
            .appendingPathExtension("m4a")

        do {
            let recorder = try recorderFactory(fileURL, recordingSettings)
            guard recorder.prepare(), recorder.start() else {
                state = .error
                throw AudioRecorderError.failedToStart
            }

            activeRecorder = recorder
            activeFileURL = fileURL
            startedAt = startDate
            state = .recording
        } catch {
            state = .error
            activeRecorder = nil
            activeFileURL = nil
            startedAt = nil
            throw error
        }
    }

    public func stopRecording() async throws -> RecordingArtifact {
        guard state == .recording,
              let recorder = activeRecorder,
              let fileURL = activeFileURL,
              let startDate = startedAt else {
            throw AudioRecorderError.notRecording
        }

        state = .saving
        recorder.stop()

        guard fileManager.fileExists(atPath: fileURL.path()) else {
            state = .error
            throw AudioRecorderError.failedToSave
        }

        let artifact = RecordingArtifact(
            fileURL: fileURL,
            duration: max(0, recorder.currentTime),
            createdAt: startDate
        )

        activeRecorder = nil
        activeFileURL = nil
        startedAt = nil
        latestArtifact = artifact
        state = .idle

        return artifact
    }

    public func cancelRecording() async {
        activeRecorder?.stop()
        if let fileURL = activeFileURL {
            try? fileManager.removeItem(at: fileURL)
        }
        activeRecorder = nil
        activeFileURL = nil
        startedAt = nil
        state = .idle
    }

    public func latestRecording() async -> RecordingArtifact? {
        latestArtifact
    }

    public func outputDirectory() async -> URL {
        capturesDirectory
    }

    public func setOutputDirectory(_ url: URL) async throws {
        guard state != .recording, state != .saving else {
            throw AudioRecorderError.alreadyRecording
        }
        capturesDirectory = try validatedOutputDirectory(url)
    }

    public static func defaultOutputDirectory(fileManager: FileManager = .default) -> URL {
        if let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloads.appendingPathComponent("KamiRecord", isDirectory: true)
        }

        return URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("captures", isDirectory: true)
    }

    private func ensureMicrophonePermission() async throws {
        let permission = permissionProvider.currentPermission()
        switch permission {
        case .authorized:
            return
        case .undetermined:
            let requested = await permissionProvider.requestPermission()
            guard requested == .authorized else {
                state = .error
                throw AudioPipelineError.microphoneDenied
            }
        case .denied, .restricted:
            state = .error
            throw AudioPipelineError.microphoneDenied
        }
    }

    private static func filename(for date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    private func validatedOutputDirectory(_ url: URL) throws -> URL {
        let directory = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw AudioRecorderError.invalidOutputDirectory
            }
            return directory
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            throw AudioRecorderError.invalidOutputDirectory
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

public actor WhisperSpeechToTextService: SpeechToTextService {
    private var mockQueue: [String]

    public init(initialMockQueue: [String] = []) {
        self.mockQueue = initialMockQueue
    }

    public func enqueueMockTranscription(_ value: String) {
        mockQueue.append(value)
    }

    public func transcribeNextUtterance(timeout: TimeInterval) async throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !mockQueue.isEmpty {
                return mockQueue.removeFirst()
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw AudioPipelineError.timeout
    }

    public func transcribeWithRetry(timeout: TimeInterval, retries: Int) async throws -> String {
        var attempts = 0
        while attempts <= retries {
            do {
                return try await transcribeNextUtterance(timeout: timeout)
            } catch AudioPipelineError.timeout {
                attempts += 1
            }
        }
        throw AudioPipelineError.maxRetriesExceeded
    }
}

@MainActor
protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ utterance: AVSpeechUtterance)
    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool
}

@MainActor
final class SystemSpeechSynthesizerAdapter: SpeechSynthesizing {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool { synthesizer.isSpeaking }

    func speak(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        synthesizer.stopSpeaking(at: boundary)
    }
}

@MainActor
public final class AVSpeechSynthesizerService: @unchecked Sendable, TextToSpeechService {
    private let synthesizer: SpeechSynthesizing
    public private(set) var interruptionCount = 0

    public init() {
        self.synthesizer = SystemSpeechSynthesizerAdapter()
    }

    init(synthesizer: SpeechSynthesizing) {
        self.synthesizer = synthesizer
    }

    public func speak(_ text: String) async throws {
        if synthesizer.isSpeaking {
            _ = synthesizer.stopSpeaking(at: .immediate)
            interruptionCount += 1
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.12
        utterance.postUtteranceDelay = 0.02
        synthesizer.speak(utterance)

        // Keep this async call cooperative for testability.
        try await Task.sleep(nanoseconds: 120_000_000)
    }

    public func stop() async {
        _ = synthesizer.stopSpeaking(at: .immediate)
    }
}
