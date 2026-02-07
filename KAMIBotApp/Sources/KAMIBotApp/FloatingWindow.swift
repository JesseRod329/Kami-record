import AppKit
import SwiftUI

struct FloatingWindowConfig: Equatable {
    var isBorderless: Bool = true
    var isFloating: Bool = true
    var isTransparent: Bool = true
    var placeTopCenter: Bool = true
    var topPadding: CGFloat = 22
}

enum FloatingWindowStyler {
    static func apply(_ config: FloatingWindowConfig, to window: NSWindow, placeTopCenter: Bool) {
        if config.isBorderless {
            window.styleMask = [.borderless, .fullSizeContentView]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
        }

        if config.isTransparent {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
        }

        if config.isFloating {
            window.level = .floating
            window.collectionBehavior.insert(.canJoinAllSpaces)
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }

        if placeTopCenter, config.placeTopCenter {
            guard let screen = window.screen ?? NSScreen.main else {
                return
            }

            let visible = screen.visibleFrame
            let frame = window.frame
            let origin = NSPoint(
                x: visible.midX - (frame.width / 2),
                y: visible.maxY - frame.height - config.topPadding
            )
            window.setFrameOrigin(origin)
        }
    }
}

struct FloatingWindowAccessor: NSViewRepresentable {
    var config: FloatingWindowConfig

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hasPlacedTopCenter = false
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }
            FloatingWindowStyler.apply(
                config,
                to: window,
                placeTopCenter: !context.coordinator.hasPlacedTopCenter
            )
            context.coordinator.hasPlacedTopCenter = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else {
                return
            }
            FloatingWindowStyler.apply(
                config,
                to: window,
                placeTopCenter: !context.coordinator.hasPlacedTopCenter
            )
            context.coordinator.hasPlacedTopCenter = true
        }
    }
}

extension View {
    func floatingWindow(config: FloatingWindowConfig = FloatingWindowConfig()) -> some View {
        background(FloatingWindowAccessor(config: config))
    }
}
