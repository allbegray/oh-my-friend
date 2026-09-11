import AppKit

public final class CharacterWindow: EntityWindow {
    public let characterView: CharacterView
    public private(set) var currentScale: CGFloat = 1.0

    private let baseSize: CGFloat = 160.0
    private let baseHeight: CGFloat = 200.0

    public init(skin: SkinTexture) {
        let frame = NSRect(x: 200, y: 200, width: baseSize, height: baseHeight)
        self.characterView = CharacterView(frame: NSRect(origin: .zero, size: frame.size), skin: skin)

        super.init(contentRect: frame, ignoresMouse: false)

        self.autoDismissDuration = 0
        self.isReleasedWhenClosed = false

        contentView = characterView
    }

    public func setScale(_ scale: CGFloat) {
        self.currentScale = scale
        let newWidth = baseSize * scale
        let newHeight = baseHeight * scale

        // Update window size preserving feet center
        let currentOrigin = frame.origin
        let centerX = currentOrigin.x + frame.width / 2.0
        let bottomY = currentOrigin.y

        let newOrigin = CGPoint(x: centerX - newWidth / 2.0, y: bottomY)
        setFrame(NSRect(origin: newOrigin, size: NSSize(width: newWidth, height: newHeight)), display: true)
        characterView.frame = NSRect(origin: .zero, size: NSSize(width: newWidth, height: newHeight))
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
