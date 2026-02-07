import Foundation

public enum PersonaExpressionMapper {
    public static func expression(for text: String) -> FaceExpression {
        let normalized = text.lowercased()

        if normalized.contains("!") || normalized.contains("awesome") || normalized.contains("great") {
            return .excited
        }

        if normalized.contains("?") || normalized.contains("maybe") || normalized.contains("wonder") {
            return .curious
        }

        if normalized.contains("sorry") || normalized.contains("oops") {
            return .squint
        }

        return .speaking
    }
}
