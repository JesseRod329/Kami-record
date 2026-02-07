import AppKit

enum NotchGeometry {
    static let hitWidth: CGFloat = 232
    static let hitHeight: CGFloat = 30
    static let panelSize = CGSize(width: 520, height: 330)
    static let panelTopGap: CGFloat = 10
    static let collapsedWidth: CGFloat = 224
    static let collapsedHeight: CGFloat = 36

    static func notchFrame(on screen: NSScreen) -> NSRect {
        let originX = screen.frame.midX - (hitWidth / 2)
        let originY = screen.frame.maxY - hitHeight
        return NSRect(x: originX, y: originY, width: hitWidth, height: hitHeight)
    }

    static func collapsedFrame(on screen: NSScreen) -> NSRect {
        let originX = screen.frame.midX - (collapsedWidth / 2)
        let originY = screen.frame.maxY - collapsedHeight
        return NSRect(x: originX, y: originY, width: collapsedWidth, height: collapsedHeight)
    }

    static func expandedFrame(on screen: NSScreen) -> NSRect {
        let width = min(panelSize.width, screen.frame.width * 0.92)
        let height = min(panelSize.height, screen.frame.height * 0.70)
        let originX = screen.frame.midX - (width / 2)
        let originY = screen.frame.maxY - hitHeight - panelTopGap - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }
}
