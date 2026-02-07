import Foundation

public protocol WakeWordService: Sendable {
    func start() async throws
    func stop() async
    func events() async -> AsyncStream<WakeWordEvent>
}

public protocol SpeechToTextService: Sendable {
    func transcribeNextUtterance(timeout: TimeInterval) async throws -> String
}

public protocol TextToSpeechService: Sendable {
    func speak(_ text: String) async throws
    func stop() async
}

public protocol LLMService: Sendable {
    func generateResponse(
        prompt: String,
        systemPrompt: String,
        context: VisionContext?
    ) async throws -> String
}

public protocol VisionService: Sendable {
    func captureSnapshotDescription() async throws -> VisionContext
}
