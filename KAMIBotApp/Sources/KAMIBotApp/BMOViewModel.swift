import AudioPipeline
import CoreAgent
import ModelRuntime
import Observation

@MainActor
@Observable
final class BMOViewModel {
    private let agent: BMOAgent
    private let audioStartupCoordinator: AudioStartupCoordinator
    private let modelStartupCoordinator: ModelStartupCoordinator
    private let startupChecks: [StartupCheckResult]
    private var streamTask: Task<Void, Never>?

    var state: BMOState = .idle
    var expression: FaceExpression = .happy
    var transcript: [String] = []

    init(
        agent: BMOAgent,
        audioStartupCoordinator: AudioStartupCoordinator,
        modelStartupCoordinator: ModelStartupCoordinator,
        startupChecks: [StartupCheckResult]
    ) {
        self.agent = agent
        self.audioStartupCoordinator = audioStartupCoordinator
        self.modelStartupCoordinator = modelStartupCoordinator
        self.startupChecks = startupChecks
    }

    func start() {
        guard streamTask == nil else {
            return
        }

        streamTask = Task {
            let failedChecks = startupChecks.filter { $0.status == .fail }
            if !failedChecks.isEmpty {
                state = .error
                for check in failedChecks {
                    transcript.append("Startup check failed (\(check.id)): \(check.message)")
                }
                streamTask = nil
                return
            }

            do {
                try await audioStartupCoordinator.prepareAudioInput()
            } catch AudioPipelineError.microphoneDenied {
                state = .error
                transcript.append("Error: Microphone permission is required.")
                streamTask = nil
                return
            } catch {
                state = .error
                transcript.append("Error: Audio startup failed: \(error.localizedDescription)")
                streamTask = nil
                return
            }

            do {
                _ = try await modelStartupCoordinator.prepareModel()
            } catch {
                state = .error
                transcript.append("Error: Model startup failed: \(error.localizedDescription)")
                streamTask = nil
                return
            }

            await agent.start()
            for await event in agent.eventStream() {
                switch event {
                case .stateChanged(let state):
                    self.state = state
                case .faceChanged(let expression):
                    self.expression = expression
                case .heardUtterance(let utterance):
                    transcript.append("You: \(utterance)")
                case .generatedResponse(let response):
                    transcript.append("BMO: \(response)")
                case .error(let message):
                    transcript.append("Error: \(message)")
                }
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        Task {
            await agent.stop()
        }
    }
}
