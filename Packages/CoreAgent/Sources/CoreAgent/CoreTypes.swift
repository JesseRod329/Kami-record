import Foundation

public enum BMOState: String, Codable, Sendable {
    case idle
    case listening
    case thinking
    case speaking
    case error
}

public enum FaceExpression: String, Codable, Sendable {
    case happy
    case neutral
    case curious
    case excited
    case squint
    case speaking
}

public struct AgentConfig: Codable, Sendable {
    public var wakeWord: String
    public var llmModelID: String
    public var visionModelID: String
    public var sttTimeoutSeconds: Double
    public var llmTimeoutSeconds: Double
    public var telemetryEnabled: Bool
    public var visionEnabled: Bool

    public init(
        wakeWord: String = "BMO",
        llmModelID: String = "llama-3.1-8b-4bit",
        visionModelID: String = "moondream",
        sttTimeoutSeconds: Double = 8.0,
        llmTimeoutSeconds: Double = 25.0,
        telemetryEnabled: Bool = false,
        visionEnabled: Bool = false
    ) {
        self.wakeWord = wakeWord
        self.llmModelID = llmModelID
        self.visionModelID = visionModelID
        self.sttTimeoutSeconds = sttTimeoutSeconds
        self.llmTimeoutSeconds = llmTimeoutSeconds
        self.telemetryEnabled = telemetryEnabled
        self.visionEnabled = visionEnabled
    }
}

public struct WakeWordEvent: Sendable {
    public var keyword: String
    public var detectedAt: Date

    public init(keyword: String, detectedAt: Date = Date()) {
        self.keyword = keyword
        self.detectedAt = detectedAt
    }
}

public struct VisionContext: Sendable {
    public var summary: String
    public var capturedAt: Date

    public init(summary: String, capturedAt: Date = Date()) {
        self.summary = summary
        self.capturedAt = capturedAt
    }
}

public enum AgentEvent: Sendable {
    case stateChanged(BMOState)
    case faceChanged(FaceExpression)
    case heardUtterance(String)
    case generatedResponse(String)
    case error(String)
}

public enum PromptRoute: String, Sendable {
    case text
    case vision
}

public enum PromptRouter {
    public static func route(for utterance: String) -> PromptRoute {
        let lowered = utterance.lowercased()
        let visionTokens = ["look", "see", "what do you see", "show", "camera", "snapshot", "vision"]
        return visionTokens.contains(where: { lowered.contains($0) }) ? .vision : .text
    }
}
