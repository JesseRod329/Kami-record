import CoreAgent
import SwiftUI

public struct BMOFaceView: View {
    public let expression: FaceExpression
    public let state: BMOState

    @Namespace private var faceNamespace

    public init(expression: FaceExpression, state: BMOState) {
        self.expression = expression
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                eyeView(left: true)
                eyeView(left: false)
            }
            mouthView
        }
        .padding(28)
        .frame(width: 220, height: 220)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: expression)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private func eyeView(left: Bool) -> some View {
        switch expression {
        case .squint:
            Capsule()
                .fill(.white)
                .frame(width: 36, height: 8)
                .matchedGeometryEffect(id: left ? "left-eye" : "right-eye", in: faceNamespace)
        default:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.white)
                .frame(width: 30, height: state == .listening ? 38 : 30)
                .matchedGeometryEffect(id: left ? "left-eye" : "right-eye", in: faceNamespace)
        }
    }

    private var mouthView: some View {
        Group {
            switch expression {
            case .excited:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white)
                    .frame(width: 66, height: 18)
            case .speaking:
                Capsule()
                    .fill(.white)
                    .frame(width: 52, height: 14)
            case .curious:
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 22, height: 22)
            default:
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 56, height: 8)
            }
        }
        .matchedGeometryEffect(id: "mouth", in: faceNamespace)
    }
}
