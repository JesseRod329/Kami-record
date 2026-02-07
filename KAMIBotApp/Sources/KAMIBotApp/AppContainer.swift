import AudioPipeline
import CryptoKit
import CoreAgent
import Foundation
import ModelRuntime
import VisionPipeline

@MainActor
struct AppContainer {
    let agent: BMOAgent
    let audioRecorderService: any AudioRecorderService
    let audioStartupCoordinator: AudioStartupCoordinator
    let modelStartupCoordinator: ModelStartupCoordinator
    let startupChecks: [StartupCheckResult]
    let modelDescriptor: ModelDescriptor

    init(config: AgentConfig = AgentConfig()) {
        let enforcedConfig = Self.enforcePolicy(config)

        let wakeWord = PorcupineWakeWordService(keyword: enforcedConfig.wakeWord)
        let stt = WhisperSpeechToTextService()
        let tts = AVSpeechSynthesizerService()
        let permissionProvider = SystemMicrophonePermissionProvider()
        let recorder = LocalAudioRecorderService(permissionProvider: permissionProvider)
        self.audioRecorderService = recorder

        let modelStore = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("models", isDirectory: true)
        let llm = MLXLLMService(modelID: enforcedConfig.llmModelID, modelStore: modelStore)
        let modelDownloader = ModelDownloader(baseDirectory: modelStore)
        let modelDescriptor = Self.resolveModelDescriptor(for: enforcedConfig, modelStore: modelStore)
        self.modelDescriptor = modelDescriptor
        self.startupChecks = StartupValidator.run(config: enforcedConfig, modelDescriptor: modelDescriptor)
        self.modelStartupCoordinator = ModelStartupCoordinator(
            downloader: modelDownloader,
            descriptor: modelDescriptor,
            llmService: llm
        )

        let vision = SnapshotVisionService(enabled: enforcedConfig.visionEnabled)
        self.audioStartupCoordinator = AudioStartupCoordinator(permissionProvider: permissionProvider)

        self.agent = BMOAgent(
            config: enforcedConfig,
            wakeWordService: wakeWord,
            sttService: stt,
            ttsService: tts,
            llmService: llm,
            visionService: vision
        )
    }

    private static func resolveModelDescriptor(for config: AgentConfig, modelStore: URL) -> ModelDescriptor {
        let env = ProcessInfo.processInfo.environment
        if let urlString = env["KAMI_BOT_MODEL_URL"],
           let url = URL(string: urlString),
           let sha = env["KAMI_BOT_MODEL_SHA256"],
           !sha.isEmpty {
            return ModelDescriptor(
                id: config.llmModelID,
                url: url,
                sha256: sha,
                license: env["KAMI_BOT_MODEL_LICENSE"] ?? "Custom"
            )
        }

        // Default dev fallback: local stub model with pinned hash for click-to-run startup.
        let stubURL = modelStore.appendingPathComponent("dev-model-stub.bin")
        let stubData = Data("KAMI BOT DEV MODEL STUB".utf8)
        let digest = SHA256.hash(data: stubData).map { String(format: "%02x", $0) }.joined()

        do {
            try FileManager.default.createDirectory(at: modelStore, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: stubURL.path()) {
                try stubData.write(to: stubURL)
            }
        } catch {
            // If local stub creation fails, keep fallback catalog behavior.
            return ModelDescriptor(
                id: config.llmModelID,
                url: ModelCatalog.llama31_8B4bit.url,
                sha256: ModelCatalog.llama31_8B4bit.sha256,
                license: ModelCatalog.llama31_8B4bit.license
            )
        }

        return ModelDescriptor(
            id: config.llmModelID,
            url: stubURL,
            sha256: digest,
            license: "Development Stub"
        )
    }

    private static func enforcePolicy(_ config: AgentConfig) -> AgentConfig {
        AgentConfig(
            wakeWord: config.wakeWord,
            llmModelID: config.llmModelID,
            visionModelID: config.visionModelID,
            sttTimeoutSeconds: config.sttTimeoutSeconds,
            llmTimeoutSeconds: config.llmTimeoutSeconds,
            telemetryEnabled: false,
            visionEnabled: config.visionEnabled
        )
    }
}
