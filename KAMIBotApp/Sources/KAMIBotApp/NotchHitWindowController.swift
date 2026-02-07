import AppKit

@MainActor
final class NotchHitWindowController {
    private let window: NSWindow
    private let hitView: NotchHitView
    private var screenObserver: NSObjectProtocol?

    init(onTap: @escaping () -> Void) {
        hitView = NotchHitView(onTap: onTap)

        window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = hitView

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateFrame(on: NSScreen.main)
            }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    var currentFrame: NSRect {
        window.frame
    }

    func show(on screen: NSScreen?) {
        updateFrame(on: screen)
        window.orderFrontRegardless()
    }

    func updateFrame(on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else {
            return
        }
        window.setFrame(NotchGeometry.notchFrame(on: screen), display: true)
    }
}

private final class NotchHitView: NSView {
    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        onTap()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }
}
