import AppKit

public final class SkeletonWindow: NSPanel {
    public let skeletonView: SkeletonView
    public private(set) var currentScale: CGFloat = 1.0

    private let baseSize: CGFloat = 135.0

    public init() {
        let frame = NSRect(x: 350, y: 200, width: baseSize, height: baseSize)
        self.skeletonView = SkeletonView(frame: NSRect(origin: .zero, size: frame.size))

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false

        contentView = skeletonView
    }

    public func setScale(_ scale: CGFloat) {
        self.currentScale = scale
        let newSize = baseSize * scale
        let currentOrigin = frame.origin
        let centerX = currentOrigin.x + frame.width / 2.0
        let bottomY = currentOrigin.y

        let newOrigin = CGPoint(x: centerX - newSize / 2.0, y: bottomY)
        setFrame(NSRect(origin: newOrigin, size: NSSize(width: newSize, height: newSize)), display: true)
        skeletonView.frame = NSRect(origin: .zero, size: NSSize(width: newSize, height: newSize))
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
