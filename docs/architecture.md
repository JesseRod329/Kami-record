# KAMI BOT Architecture

## Core Types

```swift
enum BMOState: Sendable {
    case idle
    case listening
    case thinking
    case speaking
    case error
}

enum FaceExpression: String, Sendable {
    case happy
    case neutral
    case curious
    case excited
    case squint
    case speaking
}
```

```swift
struct AgentConfig: Codable, Sendable {
    var wakeWord: String
    var llmModelID: String
    var visionModelID: String
    var sttTimeoutSeconds: Double
    var llmTimeoutSeconds: Double
    var telemetryEnabled: Bool
}
```

## Service Protocols

```swift
protocol WakeWordService
protocol SpeechToTextService
protocol TextToSpeechService
protocol LLMService
protocol VisionService
protocol AudioRecorderService
```

## Recorder Types

```swift
enum RecorderState: Sendable {
    case idle
    case recording
    case saving
    case error
}

struct RecordingArtifact: Sendable {
    let fileURL: URL
    let duration: TimeInterval
    let createdAt: Date
}
```

## Agent API

```swift
actor BMOAgent {
    func start() async
    func stop() async
    func handleWakeWordEvent() async
    func handleUserUtterance(_ utterance: String) async
    func speak(_ text: String) async
}
```

## UI Model

```swift
@MainActor @Observable final class BMOViewModel
```

The view model consumes `AsyncStream<AgentEvent>` from `BMOAgent`.

## Data Flow

1. Wake word event arrives.
2. Agent switches `idle -> listening` and captures utterance.
3. Agent routes prompt (text vs vision) then enters `thinking`.
4. LLM response is generated.
5. Agent enters `speaking`, emits face changes, and plays TTS.
6. Agent returns to `idle`.

Timeout and cancellation guards:
- STT and LLM steps run with explicit timeout wrappers.
- In-flight turn tasks are canceled on `stop()` and the agent force-recovers to `idle`.

## Recorder Flow

1. User taps `Record` in the notch-style recorder bar.
2. `RecorderViewModel` requests `AudioRecorderService.startRecording()`.
3. `LocalAudioRecorderService` validates microphone permission and starts an AAC recorder.
4. Audio writes to `captures/YYYY-MM-DD-HHMMSS.m4a`.
5. User taps `Stop`; service transitions `recording -> saving`, finalizes, and returns `RecordingArtifact`.
6. View model updates latest capture metadata and returns to `idle`.

Failure handling:
- Denied/restricted microphone permission fails fast with `AudioPipelineError.microphoneDenied`.
- Canceling an in-progress recording deletes the temporary capture file before returning to `idle`.

## UI and Windowing

- `GlassSurface` provides Tahoe-first liquid-style panels with material fallback.
- `BMOFaceView` uses `matchedGeometryEffect` for expression transitions.
- `FloatingWindowStyler` configures a borderless, transparent, always-on-top desktop companion window.
- `FloatingWindowStyler` supports top-center placement for the notch-style recorder presentation.
- `AudioStartupCoordinator` enforces microphone permission before activating wake-word listening.
- `LocalAudioRecorderService` provides one-tap start/stop/cancel capture with local file persistence.
- `ModelStartupCoordinator` performs first-run model download and hash verification before LLM use.
- `AVSpeechSynthesizerService` supports interruption-aware speaking and explicit stop behavior.
- `SettingsStore` persists wake-word and vision toggles while enforcing telemetry-off policy.
- `StartupValidator` gates agent startup on policy and manifest checks.
- `SnapshotVisionService` now supports on-demand frame-capture source wiring for v1.1.
