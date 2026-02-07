import CoreAgent
import ModelRuntime

enum StartupCheckStatus: String {
    case pass
    case fail
}

struct StartupCheckResult {
    let id: String
    let status: StartupCheckStatus
    let message: String
}

enum StartupValidator {
    static func run(config: AgentConfig, modelDescriptor: ModelDescriptor) -> [StartupCheckResult] {
        var checks: [StartupCheckResult] = []

        checks.append(
            StartupCheckResult(
                id: "telemetry",
                status: config.telemetryEnabled ? .fail : .pass,
                message: config.telemetryEnabled
                    ? "Telemetry must remain disabled by project policy."
                    : "Telemetry policy enforced (disabled)."
            )
        )

        checks.append(
            StartupCheckResult(
                id: "wake-word",
                status: config.wakeWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .fail : .pass,
                message: config.wakeWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Wake word cannot be empty."
                    : "Wake word configured."
            )
        )

        let pinnedHash = modelDescriptor.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
        checks.append(
            StartupCheckResult(
                id: "model-manifest",
                status: pinnedHash ? .pass : .fail,
                message: pinnedHash
                    ? "Model manifest is hash-pinned."
                    : "Model manifest hash is not pinned. Set KAMI_BOT_MODEL_SHA256 to a 64-char digest."
            )
        )

        return checks
    }
}
