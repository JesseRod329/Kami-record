import SwiftUI

public enum GlassAppearance: Equatable, Sendable {
    case liquid
    case materialFallback
}

public enum GlassStyleResolver {
    public static func resolve(osMajorVersion: Int) -> GlassAppearance {
        osMajorVersion >= 26 ? .liquid : .materialFallback
    }
}

public struct GlassSurface<Content: View>: View {
    private let appearance: GlassAppearance
    private let content: Content

    public init(
        osMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        @ViewBuilder content: () -> Content
    ) {
        self.appearance = GlassStyleResolver.resolve(osMajorVersion: osMajorVersion)
        self.content = content()
    }

    public var body: some View {
        content
            .padding(14)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch appearance {
        case .liquid:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .materialFallback:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}
