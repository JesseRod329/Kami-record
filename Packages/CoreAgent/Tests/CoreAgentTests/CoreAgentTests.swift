import Foundation
import XCTest
@testable import CoreAgent

private actor MockWakeWordService: WakeWordService {
    private var continuation: AsyncStream<WakeWordEvent>.Continuation?
    private lazy var stream: AsyncStream<WakeWordEvent> = {
        AsyncStream<WakeWordEvent> { continuation in
            self.continuation = continuation
        }
    }()

    func start() async throws {}
    func stop() async {}
    func events() async -> AsyncStream<WakeWordEvent> { stream }

    func emit(keyword: String) {
        continuation?.yield(WakeWordEvent(keyword: keyword))
    }
}

private actor MockSTTService: SpeechToTextService {
    var value: String = "hello"
    var delayNanoseconds: UInt64 = 0

    func setDelayNanoseconds(_ value: UInt64) {
        delayNanoseconds = value
    }

    func transcribeNextUtterance(timeout: TimeInterval) async throws -> String {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return value
    }
}

private actor MockTTSService: TextToSpeechService {
    private(set) var spoken: [String] = []
    func speak(_ text: String) async throws { spoken.append(text) }
    func stop() async {}
}

private actor MockLLMService: LLMService {
    private(set) var requests: [String] = []
    var delayNanoseconds: UInt64 = 0

    func generateResponse(prompt: String, systemPrompt: String, context: VisionContext?) async throws -> String {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        requests.append(prompt)
        return "Hi from BMO!"
    }
}

private actor MockVisionService: VisionService {
    func captureSnapshotDescription() async throws -> VisionContext {
        VisionContext(summary: "A desk with a keyboard")
    }
}

final class CoreAgentTests: XCTestCase {
    func testStateTransitionValidationRejectsInvalidPath() {
        XCTAssertFalse(BMOAgent.isValidTransition(from: .idle, to: .thinking))
        XCTAssertTrue(BMOAgent.isValidTransition(from: .idle, to: .listening))
    }

    func testPromptRouterRoutesVisionRequests() {
        XCTAssertEqual(PromptRouter.route(for: "What do you see right now?"), .vision)
        XCTAssertEqual(PromptRouter.route(for: "Tell me a joke"), .text)
    }

    func testPersonaExpressionMapping() {
        XCTAssertEqual(PersonaExpressionMapper.expression(for: "Awesome!"), .excited)
        XCTAssertEqual(PersonaExpressionMapper.expression(for: "Maybe?"), .curious)
        XCTAssertEqual(PersonaExpressionMapper.expression(for: "Sorry"), .squint)
        XCTAssertEqual(PersonaExpressionMapper.expression(for: "Okay"), .speaking)
    }

    func testAgentPipelineWithMocks() async {
        let wake = MockWakeWordService()
        let stt = MockSTTService()
        let tts = MockTTSService()
        let llm = MockLLMService()
        let vision = MockVisionService()

        let agent = BMOAgent(
            config: AgentConfig(visionEnabled: true),
            wakeWordService: wake,
            sttService: stt,
            ttsService: tts,
            llmService: llm,
            visionService: vision
        )

        await agent.start()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await wake.emit(keyword: "BMO")
        try? await Task.sleep(nanoseconds: 450_000_000)

        let state = await agent.state
        XCTAssertEqual(state, .idle)

        let spoken = await tts.spoken
        XCTAssertEqual(spoken.count, 1)
        XCTAssertEqual(spoken.first, "Hi from BMO!")
    }

    func testAgentRecoversToIdleAfterSTTTimeout() async {
        let wake = MockWakeWordService()
        let stt = MockSTTService()
        let tts = MockTTSService()
        let llm = MockLLMService()
        let vision = MockVisionService()
        await stt.setDelayNanoseconds(300_000_000)

        let agent = BMOAgent(
            config: AgentConfig(sttTimeoutSeconds: 0.05),
            wakeWordService: wake,
            sttService: stt,
            ttsService: tts,
            llmService: llm,
            visionService: vision
        )

        await agent.handleWakeWordEvent()
        try? await Task.sleep(nanoseconds: 120_000_000)

        let state = await agent.state
        XCTAssertEqual(state, .idle)
    }

    func testStopCancelsInFlightTurn() async {
        let wake = MockWakeWordService()
        let stt = MockSTTService()
        let tts = MockTTSService()
        let llm = MockLLMService()
        let vision = MockVisionService()
        await stt.setDelayNanoseconds(2_000_000_000)

        let agent = BMOAgent(
            config: AgentConfig(sttTimeoutSeconds: 5.0),
            wakeWordService: wake,
            sttService: stt,
            ttsService: tts,
            llmService: llm,
            visionService: vision
        )

        let turn = Task {
            await agent.handleWakeWordEvent()
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
        await agent.stop()
        _ = await turn.value

        let state = await agent.state
        XCTAssertEqual(state, .idle)
    }
}
