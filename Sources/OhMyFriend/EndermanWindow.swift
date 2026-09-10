import AppKit

public final class EndermanWindow: EntityWindow {
    public let endermanView: EndermanView
    public private(set) var currentScale: CGFloat = 1.0

    private let baseWidth: CGFloat = 140.0
    private let baseHeight: CGFloat = 180.0 // Taller window for tall Enderman

    public init() {
        let frame = NSRect(x: 400, y: 200, width: baseWidth, height: baseHeight)
        self.endermanView = EndermanView(frame: NSRect(origin: .zero, size: frame.size))

        super.init(contentRect: frame, ignoresMouse: false)

        self.isReleasedWhenClosed = false

        contentView = endermanView
    }

    public func setScale(_ scale: CGFloat) {
        self.currentScale = scale
        let newW = baseWidth * scale
        let newH = baseHeight * scale
        let currentOrigin = frame.origin
        let centerX = currentOrigin.x + frame.width / 2.0
        let bottomY = currentOrigin.y

        let newOrigin = CGPoint(x: centerX - newW / 2.0, y: bottomY)
        setFrame(NSRect(origin: newOrigin, size: NSSize(width: newW, height: newH)), display: true)
        endermanView.frame = NSRect(origin: .zero, size: NSSize(width: newW, height: newH))
    }

    public func setFeetPosition(x footX: CGFloat, y footY: CGFloat) {
        let winW = frame.width
        let originX = footX - (winW / 2.0)
        let originY = footY - (8.0 * currentScale)
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }
}
