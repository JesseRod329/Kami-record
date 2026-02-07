import Foundation

public enum AgentError: Error, Equatable {
    case invalidTransition(from: BMOState, to: BMOState)
    case unavailable(String)
    case timeout(String)
}

public actor BMOAgent {
    public private(set) var state: BMOState = .idle
    public private(set) var faceExpression: FaceExpression = .happy

    private let config: AgentConfig
    private let wakeWordService: WakeWordService
    private let sttService: SpeechToTextService
    private let ttsService: TextToSpeechService
    private let llmService: LLMService
    private let visionService: VisionService?

    private var wakeTask: Task<Void, Never>?
    private var turnTask: Task<Void, Never>?
    private let stream: AsyncStream<AgentEvent>
    private let continuation: AsyncStream<AgentEvent>.Continuation

    public init(
        config: AgentConfig,
        wakeWordService: WakeWordService,
        sttService: SpeechToTextService,
        ttsService: TextToSpeechService,
        llmService: LLMService,
        visionService: VisionService?
    ) {
        self.config = config
        self.wakeWordService = wakeWordService
        self.sttService = sttService
        self.ttsService = ttsService
        self.llmService = llmService
        self.visionService = visionService

        var localContinuation: AsyncStream<AgentEvent>.Continuation?
        self.stream = AsyncStream<AgentEvent> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation!
    }

    deinit {
        wakeTask?.cancel()
        turnTask?.cancel()
        continuation.finish()
    }

    public nonisolated func eventStream() -> AsyncStream<AgentEvent> {
        stream
    }

    public func start() async {
        do {
            try await wakeWordService.start()
            wakeTask = Task {
                let events = await wakeWordService.events()
                for await event in events {
                    if Task.isCancelled {
                        break
                    }
                    if event.keyword.caseInsensitiveCompare(config.wakeWord) == .orderedSame {
                        await self.handleWakeWordEvent()
                    }
                }
            }
        } catch {
            emitError("Wake word service failed to start: \(error.localizedDescription)")
        }
    }

    public func stop() async {
        wakeTask?.cancel()
        wakeTask = nil
        turnTask?.cancel()
        turnTask = nil
        await wakeWordService.stop()
        await ttsService.stop()
        forceState(.idle)
    }

    public func handleWakeWordEvent() async {
        guard turnTask == nil else {
            return
        }

        turnTask = Task {
            await self.processTurn()
        }

        await turnTask?.value
        turnTask = nil
    }

    public func handleUserUtterance(_ utterance: String) async {
        do {
            try transition(to: .thinking)

            let route = PromptRouter.route(for: utterance)
            let visionContext: VisionContext?

            if route == .vision && config.visionEnabled {
                guard let visionService else {
                    throw AgentError.unavailable("Vision requested but service is not configured")
                }
                visionContext = try await visionService.captureSnapshotDescription()
            } else {
                visionContext = nil
            }

            let response = try await withTimeout(
                seconds: config.llmTimeoutSeconds,
                label: "LLM generation"
            ) { [llmService] in
                try await llmService.generateResponse(
                    prompt: utterance,
                    systemPrompt: "You are BMO, an upbeat and helpful desktop companion.",
                    context: visionContext
                )
            }

            continuation.yield(.generatedResponse(response))
            await speak(response)
        } catch {
            emitError("Agent processing failed: \(error.localizedDescription)")
            recoverToIdle()
        }
    }

    public func speak(_ text: String) async {
        do {
            try transition(to: .speaking)
            let expression = expression(for: text)
            faceExpression = expression
            continuation.yield(.faceChanged(expression))
            try await ttsService.speak(text)
            faceExpression = .happy
            continuation.yield(.faceChanged(.happy))
            try transition(to: .idle)
        } catch {
            emitError("TTS failed: \(error.localizedDescription)")
            recoverToIdle()
        }
    }

    public static func isValidTransition(from: BMOState, to: BMOState) -> Bool {
        switch (from, to) {
        case (.idle, .listening), (.idle, .error):
            true
        case (.listening, .thinking), (.listening, .idle), (.listening, .error):
            true
        case (.thinking, .speaking), (.thinking, .idle), (.thinking, .error):
            true
        case (.speaking, .idle), (.speaking, .error):
            true
        case (.error, .idle):
            true
        case (let lhs, let rhs):
            lhs == rhs
        }
    }

    private func transition(to next: BMOState) throws {
        guard Self.isValidTransition(from: state, to: next) else {
            throw AgentError.invalidTransition(from: state, to: next)
        }
        state = next
        continuation.yield(.stateChanged(next))
    }

    private func expression(for text: String) -> FaceExpression {
        PersonaExpressionMapper.expression(for: text)
    }

    private func emitError(_ message: String) {
        state = .error
        continuation.yield(.stateChanged(.error))
        continuation.yield(.error(message))
    }

    private func processTurn() async {
        do {
            try transition(to: .listening)
            let utterance = try await withTimeout(
                seconds: config.sttTimeoutSeconds,
                label: "STT transcription"
            ) { [sttService, config] in
                try await sttService.transcribeNextUtterance(timeout: config.sttTimeoutSeconds)
            }
            continuation.yield(.heardUtterance(utterance))
            await handleUserUtterance(utterance)
        } catch {
            if error is CancellationError {
                recoverToIdle()
                return
            }
            emitError("Transcription failed: \(error.localizedDescription)")
            recoverToIdle()
        }
    }

    private func recoverToIdle() {
        forceState(.idle)
    }

    private func forceState(_ next: BMOState) {
        state = next
        continuation.yield(.stateChanged(next))
    }

    private func withTimeout<T: Sendable>(
        seconds: Double,
        label: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AgentError.timeout("\(label) exceeded \(seconds)s")
            }

            guard let first = try await group.next() else {
                throw AgentError.timeout("\(label) did not return a result")
            }
            group.cancelAll()
            return first
        }
    }
}
