import CoreAgent

public enum PersonaPromptBuilder {
    public static func makePrompt(userPrompt: String, visionContext: VisionContext?) -> String {
        let persona = "You are BMO. Keep responses concise, kind, and playful."

        if let visionContext {
            return "\(persona)\nVision context: \(visionContext.summary)\nUser: \(userPrompt)"
        }

        return "\(persona)\nUser: \(userPrompt)"
    }
}
