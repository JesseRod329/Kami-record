import AppKit
import SwiftUI

@MainActor
final class RecorderPanelWindowController {
    private let panel: NSPanel
    private weak var anchorScreen: NSScreen?

    private let expandDuration: TimeInterval = 0.30
    private let collapseDuration: TimeInterval = 0.22

    init(rootView: AnyView) {
        let hostView = NSHostingView(rootView: rootView)

        panel = RecorderPanel(
            contentRect: NSRect(origin: .zero, size: NotchGeometry.panelSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostView
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func expand(from notchFrame: NSRect, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else {
            return
        }
        anchorScreen = screen

        let expandedFrame = NotchGeometry.expandedFrame(on: screen)
        panel.alphaValue = 0.94
        panel.setFrame(notchFrame, display: false)
        panel.makeKeyAndOrderFront(nil)
        PanelAnimator.animate(panel: panel, to: expandedFrame, duration: expandDuration, alpha: 1)
    }

    func collapse(to notchFrame: NSRect, on screen: NSScreen?) {
        guard panel.isVisible else {
            return
        }

        let targetFrame: NSRect
        if let screen = screen ?? anchorScreen ?? NSScreen.main {
            targetFrame = NotchGeometry.collapsedFrame(on: screen)
        } else {
            targetFrame = notchFrame
        }

        PanelAnimator.animate(panel: panel, to: targetFrame, duration: collapseDuration, alpha: 0.92)
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration) { [weak self] in
            self?.panel.orderOut(nil)
            self?.panel.alphaValue = 1
        }
    }

    func reposition(on screen: NSScreen?) {
        guard let screen = screen ?? anchorScreen ?? NSScreen.main else {
            return
        }
        anchorScreen = screen

        let frame = panel.isVisible ? NotchGeometry.expandedFrame(on: screen) : NotchGeometry.collapsedFrame(on: screen)
        panel.setFrame(frame, display: true)
    }
}

private final class RecorderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
