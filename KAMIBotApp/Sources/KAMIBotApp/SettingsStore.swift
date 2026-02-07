import CoreAgent
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let wakeWord = "settings.wakeWord"
        static let visionEnabled = "settings.visionEnabled"
        static let telemetryEnabled = "settings.telemetryEnabled"
    }

    var wakeWord: String {
        didSet {
            wakeWord = wakeWord.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var visionEnabled: Bool

    var telemetryEnabled: Bool {
        didSet {
            // Project policy: telemetry is disabled by default and enforced off.
            if telemetryEnabled {
                telemetryEnabled = false
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        let storedWakeWord = defaults.string(forKey: Keys.wakeWord) ?? "BMO"
        self.wakeWord = storedWakeWord.trimmingCharacters(in: .whitespacesAndNewlines)
        self.visionEnabled = defaults.object(forKey: Keys.visionEnabled) as? Bool ?? false
        self.telemetryEnabled = false
    }

    func toAgentConfig() -> AgentConfig {
        AgentConfig(
            wakeWord: wakeWord.isEmpty ? "BMO" : wakeWord,
            llmModelID: "llama-3.1-8b-4bit",
            visionModelID: "moondream",
            sttTimeoutSeconds: 8.0,
            llmTimeoutSeconds: 25.0,
            telemetryEnabled: false,
            visionEnabled: visionEnabled
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(wakeWord, forKey: Keys.wakeWord)
        defaults.set(visionEnabled, forKey: Keys.visionEnabled)
        defaults.set(false, forKey: Keys.telemetryEnabled)
    }
}
