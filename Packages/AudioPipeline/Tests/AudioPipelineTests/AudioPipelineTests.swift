import Foundation
import AVFoundation
import XCTest
@testable import AudioPipeline

private final class MockPermissionProvider: @unchecked Sendable, MicrophonePermissionProviding {
    var current: MicrophonePermissionState
    var requested: MicrophonePermissionState

    init(current: MicrophonePermissionState, requested: MicrophonePermissionState) {
        self.current = current
        self.requested = requested
    }

    func currentPermission() -> MicrophonePermissionState {
        current
    }

    func requestPermission() async -> MicrophonePermissionState {
        requested
    }
}

final class AudioPipelineTests: XCTestCase {
    func testWakeWordDebounceSuppressesDuplicates() async {
        let service = PorcupineWakeWordService(keyword: "BMO", debounceSeconds: 1.0)
        try? await service.start()

        let stream = await service.events()
        let task = Task<[String], Never> {
            var output: [String] = []
            for await event in stream {
                output.append(event.keyword)
                if output.count == 2 {
                    break
                }
            }
            return output
        }

        let t0 = Date()
        await service.emitDetection(now: t0)
        await service.emitDetection(now: t0.addingTimeInterval(0.2))
        await service.emitDetection(now: t0.addingTimeInterval(1.2))

        let result = await task.value
        XCTAssertEqual(result.count, 2)
    }

    func testSTTTimeoutAndRetryPolicy() async {
        let service = WhisperSpeechToTextService()

        do {
            _ = try await service.transcribeWithRetry(timeout: 0.05, retries: 1)
            XCTFail("Expected maxRetriesExceeded")
        } catch AudioPipelineError.maxRetriesExceeded {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await service.enqueueMockTranscription("hello bmo")
        do {
            let transcription = try await service.transcribeWithRetry(timeout: 0.2, retries: 1)
            XCTAssertEqual(transcription, "hello bmo")
        } catch {
            XCTFail("Unexpected retry failure: \(error)")
        }
    }

    func testAudioStartupCoordinatorRejectsDeniedPermission() async {
        let provider = MockPermissionProvider(current: .denied, requested: .denied)
        let coordinator = AudioStartupCoordinator(permissionProvider: provider)

        do {
            try await coordinator.prepareAudioInput()
            XCTFail("Expected microphoneDenied error")
        } catch AudioPipelineError.microphoneDenied {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAudioStartupCoordinatorRequestsPermissionWhenUndetermined() async {
        let provider = MockPermissionProvider(current: .undetermined, requested: .authorized)
        let coordinator = AudioStartupCoordinator(permissionProvider: provider)

        do {
            try await coordinator.prepareAudioInput()
        } catch {
            XCTFail("Expected permission flow to succeed: \(error)")
        }
    }

    func testRecorderStartStopCreatesArtifactAndPersistsLatest() async {
        let capturesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: capturesDir) }

        let provider = MockPermissionProvider(current: .authorized, requested: .authorized)
        let dates = SequentialDateProvider([
            Date(timeIntervalSince1970: 1000),
            Date(timeIntervalSince1970: 1006)
        ])

        let service = LocalAudioRecorderService(
            permissionProvider: provider,
            capturesDirectory: capturesDir,
            now: { dates.next() },
            recorderFactory: { url, _ in
                MockAudioRecordingSession(url: url, currentTime: 6.0)
            }
        )

        do {
            try await service.startRecording()
            let artifact = try await service.stopRecording()
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.fileURL.path()))
            XCTAssertEqual(artifact.duration, 6.0, accuracy: 0.001)

            let latest = await service.latestRecording()
            XCTAssertEqual(latest?.fileURL, artifact.fileURL)
            XCTAssertEqual(latest?.createdAt, artifact.createdAt)
        } catch {
            XCTFail("Expected recorder start/stop to succeed: \(error)")
        }
    }

    func testRecorderCancelRemovesInProgressFile() async {
        let capturesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: capturesDir) }

        let provider = MockPermissionProvider(current: .authorized, requested: .authorized)
        let service = LocalAudioRecorderService(
            permissionProvider: provider,
            capturesDirectory: capturesDir,
            now: { Date() },
            recorderFactory: { url, _ in
                MockAudioRecordingSession(url: url, currentTime: 0.4)
            }
        )

        do {
            try await service.startRecording()
            await service.cancelRecording()
        } catch {
            XCTFail("Expected recorder start/cancel to succeed: \(error)")
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: capturesDir,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(files.isEmpty)
    }

    func testRecorderStartFailsWhenPermissionDenied() async {
        let capturesDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: capturesDir) }

        let provider = MockPermissionProvider(current: .denied, requested: .denied)
        let service = LocalAudioRecorderService(
            permissionProvider: provider,
            capturesDirectory: capturesDir,
            now: { Date() },
            recorderFactory: { url, _ in
                MockAudioRecordingSession(url: url)
            }
        )

        do {
            try await service.startRecording()
            XCTFail("Expected microphone denied")
        } catch AudioPipelineError.microphoneDenied {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRecorderCanSwitchOutputDirectory() async {
        let firstDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let secondDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: firstDir)
            try? FileManager.default.removeItem(at: secondDir)
        }

        let provider = MockPermissionProvider(current: .authorized, requested: .authorized)
        let service = LocalAudioRecorderService(
            permissionProvider: provider,
            capturesDirectory: firstDir,
            now: { Date() },
            recorderFactory: { url, _ in
                MockAudioRecordingSession(url: url)
            }
        )

        do {
            try await service.setOutputDirectory(secondDir)
            try await service.startRecording()
            let artifact = try await service.stopRecording()
            XCTAssertTrue(artifact.fileURL.path.hasPrefix(secondDir.path))
        } catch {
            XCTFail("Expected recorder directory switch to succeed: \(error)")
        }
    }

    @MainActor
    func testTTSSpeakInterruptsActiveUtterance() async {
        let synth = MockSpeechSynthesizer(initiallySpeaking: true)
        let service = AVSpeechSynthesizerService(synthesizer: synth)

        do {
            try await service.speak("First interruption test")
        } catch {
            XCTFail("Unexpected TTS error: \(error)")
        }

        XCTAssertEqual(synth.stopCallCount, 1)
        XCTAssertEqual(service.interruptionCount, 1)
        XCTAssertEqual(synth.speakCallCount, 1)
    }

    @MainActor
    func testTTSStopCancelsSpeech() async {
        let synth = MockSpeechSynthesizer(initiallySpeaking: true)
        let service = AVSpeechSynthesizerService(synthesizer: synth)
        await service.stop()
        XCTAssertEqual(synth.stopCallCount, 1)
        XCTAssertFalse(synth.isSpeaking)
    }
}

@MainActor
private final class MockSpeechSynthesizer: SpeechSynthesizing {
    var isSpeaking: Bool
    private(set) var stopCallCount = 0
    private(set) var speakCallCount = 0

    init(initiallySpeaking: Bool) {
        self.isSpeaking = initiallySpeaking
    }

    func speak(_ utterance: AVSpeechUtterance) {
        speakCallCount += 1
        isSpeaking = true
    }

    func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool {
        stopCallCount += 1
        isSpeaking = false
        return true
    }
}

private final class SequentialDateProvider: @unchecked Sendable {
    private var values: [Date]

    init(_ values: [Date]) {
        self.values = values
    }

    func next() -> Date {
        guard !values.isEmpty else {
            return Date()
        }
        return values.removeFirst()
    }
}

private final class MockAudioRecordingSession: AudioRecordingSession {
    private let url: URL
    private let initialDuration: TimeInterval
    private var didStart = false

    init(url: URL, currentTime: TimeInterval = 1.0) {
        self.url = url
        self.initialDuration = currentTime
    }

    var isRecording: Bool { didStart }
    var currentTime: TimeInterval { initialDuration }

    func prepare() -> Bool {
        true
    }

    func start() -> Bool {
        didStart = true
        FileManager.default.createFile(atPath: url.path(), contents: Data("audio".utf8))
        return true
    }

    func stop() {
        didStart = false
    }
}
