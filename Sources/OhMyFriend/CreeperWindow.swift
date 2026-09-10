import AppKit

public final class CreeperWindow: EntityWindow {
    public let creeperView: CreeperView
    public private(set) var currentScale: CGFloat = 1.0

    private let baseSize: CGFloat = 130.0

    public init() {
        let frame = NSRect(x: 300, y: 200, width: baseSize, height: baseSize)
        self.creeperView = CreeperView(frame: NSRect(origin: .zero, size: frame.size))

        super.init(contentRect: frame, ignoresMouse: false)

        self.isReleasedWhenClosed = false

        contentView = creeperView
    }

    public func setScale(_ scale: CGFloat) {
        self.currentScale = scale
        let newSize = baseSize * scale
        let currentOrigin = frame.origin
        let centerX = currentOrigin.x + frame.width / 2.0
        let bottomY = currentOrigin.y

        let newOrigin = CGPoint(x: centerX - newSize / 2.0, y: bottomY)
        setFrame(NSRect(origin: newOrigin, size: NSSize(width: newSize, height: newSize)), display: true)
        creeperView.frame = NSRect(origin: .zero, size: NSSize(width: newSize, height: newSize))
    }

    public func setFeetPosition(x footX: CGFloat, y footY: CGFloat) {
        let winW = frame.width
        let originX = footX - (winW / 2.0)
        let originY = footY - (10.0 * currentScale)
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }
}
