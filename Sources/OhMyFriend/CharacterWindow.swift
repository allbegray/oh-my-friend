import AppKit

public final class CharacterWindow: NSPanel {
    public let characterView: CharacterView
    public private(set) var currentScale: CGFloat = 1.0

    private let baseSize: CGFloat = 160.0

    public init(skin: SkinTexture) {
        let frame = NSRect(x: 200, y: 200, width: baseSize, height: baseSize)
        self.characterView = CharacterView(frame: NSRect(origin: .zero, size: frame.size), skin: skin)

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

        contentView = characterView
    }

    public func setScale(_ scale: CGFloat) {
        self.currentScale = scale
        let newSize = baseSize * scale

        // Update window size preserving feet center
        let currentOrigin = frame.origin
        let centerX = currentOrigin.x + frame.width / 2.0
        let bottomY = currentOrigin.y

        let newOrigin = CGPoint(x: centerX - newSize / 2.0, y: bottomY)
        setFrame(NSRect(origin: newOrigin, size: NSSize(width: newSize, height: newSize)), display: true)
        characterView.frame = NSRect(origin: .zero, size: NSSize(width: newSize, height: newSize))
    }

    /// Move window so that character's feet touch (footX, footY)
    public func setFeetPosition(x footX: CGFloat, y footY: CGFloat) {
        let winW = frame.width
        // In CharacterView, feet are at Y = 0 (bottom padding ~12 pt)
        let originX = footX - (winW / 2.0)
        let originY = footY - (12.0 * currentScale)
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    public override var canBecomeKey: Bool {
        return false
    }

    public override var canBecomeMain: Bool {
        return false
    }
}
