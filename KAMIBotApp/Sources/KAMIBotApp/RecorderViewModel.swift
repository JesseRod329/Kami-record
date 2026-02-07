import AudioPipeline
import Foundation
import Observation

@MainActor
@Observable
final class RecorderViewModel {
    private let recorderService: any AudioRecorderService
    private let now: @Sendable () -> Date
    private var meteringTask: Task<Void, Never>?
    private var recordingStartedAt: Date?

    var state: RecorderState = .idle
    var elapsedTime: TimeInterval = 0
    var audioLevel: Double = 0
    var latestRecording: RecordingArtifact?
    var errorMessage: String?

    init(
        recorderService: any AudioRecorderService,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.recorderService = recorderService
        self.now = now
    }

    var isRecording: Bool {
        state == .recording
    }

    var primaryButtonTitle: String {
        isRecording ? "Stop" : "Record"
    }

    var statusText: String {
        switch state {
        case .idle:
            "Idle"
        case .recording:
            "Recording"
        case .saving:
            "Saving"
        case .error:
            "Error"
        }
    }

    var elapsedLabel: String {
        Self.elapsedFormatter.string(from: elapsedTime) ?? "00:00"
    }

    func refreshLatestRecording() async {
        latestRecording = await recorderService.latestRecording()
    }

    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    func startRecording() async {
        guard state != .recording, state != .saving else {
            return
        }

        errorMessage = nil
        elapsedTime = 0
        audioLevel = 0

        do {
            try await recorderService.startRecording()
            recordingStartedAt = now()
            state = .recording
            startMeteringLoop()
        } catch AudioPipelineError.microphoneDenied {
            state = .error
            errorMessage = "Microphone permission is required to start recording."
        } catch {
            state = .error
            errorMessage = "Unable to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        guard state == .recording else {
            return
        }

        state = .saving
        stopMeteringLoop(resetElapsed: false)

        do {
            let artifact = try await recorderService.stopRecording()
            latestRecording = artifact
            elapsedTime = artifact.duration
            state = .idle
            recordingStartedAt = nil
        } catch {
            state = .error
            errorMessage = "Unable to save recording: \(error.localizedDescription)"
        }
    }

    func cancelRecording() async {
        stopMeteringLoop(resetElapsed: true)
        await recorderService.cancelRecording()
        state = .idle
        errorMessage = nil
        recordingStartedAt = nil
    }

    private func startMeteringLoop() {
        meteringTask?.cancel()
        meteringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let self else {
                    return
                }
                await MainActor.run {
                    self.updateMeterTick()
                }
            }
        }
    }

    private func stopMeteringLoop(resetElapsed: Bool) {
        meteringTask?.cancel()
        meteringTask = nil
        audioLevel = 0
        if resetElapsed {
            elapsedTime = 0
        }
    }

    private func updateMeterTick() {
        guard state == .recording, let recordingStartedAt else {
            return
        }

        let elapsed = max(0, now().timeIntervalSince(recordingStartedAt))
        elapsedTime = elapsed

        let oscillation = abs(sin(elapsed * 4.8))
        audioLevel = 0.18 + (oscillation * 0.82)
    }

    private static let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
