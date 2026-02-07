import AppKit
import QuartzCore

enum PanelAnimator {
    @MainActor
    static func animate(
        panel: NSPanel,
        to frame: NSRect,
        duration: TimeInterval,
        alpha: CGFloat,
        timing: CAMediaTimingFunctionName = .easeOut
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timing)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = alpha
        }
    }
}
