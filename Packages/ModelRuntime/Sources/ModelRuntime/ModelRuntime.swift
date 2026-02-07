import CoreAgent
import CryptoKit
import Foundation

public protocol LLMGenerating: Sendable {
    func generate(systemPrompt: String, prompt: String) async throws -> String
}

public struct PromptEchoEngine: LLMGenerating {
    public init() {}

    public func generate(systemPrompt: String, prompt: String) async throws -> String {
        let prefix = "[BMO]"
        return "\(prefix) \(prompt)"
    }
}

public struct ModelDescriptor: Sendable, Codable {
    public var id: String
    public var url: URL
    public var sha256: String
    public var license: String

    public init(id: String, url: URL, sha256: String, license: String) {
        self.id = id
        self.url = url
        self.sha256 = sha256
        self.license = license
    }
}

public enum ModelCatalog {
    public static let llama31_8B4bit = ModelDescriptor(
        id: "llama-3.1-8b-4bit",
        url: URL(string: "https://huggingface.co/mlx-community/Meta-Llama-3.1-8B-Instruct-4bit/resolve/main/model.safetensors")!,
        // Placeholder hash until release packaging flow pins a verified artifact.
        sha256: "replace-with-verified-sha256-from-release-manifest",
        license: "Llama 3.1 Community License"
    )
}

public enum ModelRuntimeError: Error, Equatable {
    case modelNotFound(String)
    case downloadFailed(String)
    case hashMismatch(expected: String, got: String)
    case invalidManifest(String)
}

public actor ModelDownloader {
    public let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public func ensureModelAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        let destination = baseDirectory.appendingPathComponent(descriptor.id)

        if FileManager.default.fileExists(atPath: destination.path()) {
            return destination
        }

        let hashPattern = #"^[a-f0-9]{64}$"#
        if descriptor.sha256.range(of: hashPattern, options: .regularExpression) == nil {
            throw ModelRuntimeError.invalidManifest("Model SHA256 must be a pinned 64-char lowercase hex digest")
        }

        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        do {
            let data: Data
            if descriptor.url.isFileURL {
                data = try Data(contentsOf: descriptor.url)
            } else {
                let (remoteData, _) = try await URLSession.shared.data(from: descriptor.url)
                data = remoteData
            }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == descriptor.sha256 else {
                throw ModelRuntimeError.hashMismatch(expected: descriptor.sha256, got: digest)
            }
            try data.write(to: destination)
            return destination
        } catch let error as ModelRuntimeError {
            throw error
        } catch {
            throw ModelRuntimeError.downloadFailed(error.localizedDescription)
        }
    }
}

public actor MLXLLMService: LLMService {
    private let modelID: String
    private let modelStore: URL
    private let engine: any LLMGenerating
    private(set) var loadedModelPath: URL?

    public init(
        modelID: String,
        modelStore: URL,
        engine: any LLMGenerating = PromptEchoEngine()
    ) {
        self.modelID = modelID
        self.modelStore = modelStore
        self.engine = engine
    }

    public func loadIfNeeded() throws {
        let candidate = modelStore.appendingPathComponent(modelID)
        guard FileManager.default.fileExists(atPath: candidate.path()) else {
            throw ModelRuntimeError.modelNotFound(modelID)
        }
        loadedModelPath = candidate
    }

    public func generateResponse(
        prompt: String,
        systemPrompt: String,
        context: VisionContext?
    ) async throws -> String {
        if loadedModelPath == nil {
            try loadIfNeeded()
        }

        let llmPrompt = PersonaPromptBuilder.makePrompt(userPrompt: prompt, visionContext: context)
        let runtimePrompt = "\(systemPrompt)\n\n\(llmPrompt)"
        return try await engine.generate(systemPrompt: systemPrompt, prompt: runtimePrompt)
    }
}

public actor ModelStartupCoordinator {
    private let downloader: ModelDownloader
    private let descriptor: ModelDescriptor
    private let llmService: MLXLLMService

    public init(
        downloader: ModelDownloader,
        descriptor: ModelDescriptor,
        llmService: MLXLLMService
    ) {
        self.downloader = downloader
        self.descriptor = descriptor
        self.llmService = llmService
    }

    @discardableResult
    public func prepareModel() async throws -> URL {
        let localURL = try await downloader.ensureModelAvailable(descriptor)
        try await llmService.loadIfNeeded()
        return localURL
    }
}
