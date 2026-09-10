import AppKit
import CoreGraphics

public final class EnchantTableWindow: NSPanel {
    private let onEnchant: () -> Void

    public init(floorPos: CGPoint, onEnchant: @escaping () -> Void) {
        self.onEnchant = onEnchant
        let size = NSSize(width: 80, height: 76)
        super.init(
            contentRect: NSRect(
                x: floorPos.x - size.width / 2.0,
                y: floorPos.y,
                width: size.width,
                height: size.height
            ),
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
        contentView = EnchantTableDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        onEnchant()
    }
}

private final class EnchantTableDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.15, green: 0.12, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 0, width: w - 20, height: 26))
        ctx.setFillColor(red: 0.55, green: 0.10, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 26, width: w - 20, height: 6))
        ctx.setFillColor(red: 0.75, green: 0.15, blue: 0.45, alpha: 1.0)
        ctx.saveGState()
        ctx.translateBy(x: w / 2.0, y: 44)
        ctx.rotate(by: -0.15)
        ctx.fill(CGRect(x: -16, y: -4, width: 32, height: 8))
        ctx.restoreGState()
        ctx.setFillColor(red: 0.65, green: 0.35, blue: 0.95, alpha: 0.9)
        for x in [16, 28, 52, 62] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: x, y: 56 + (x.truncatingRemainder(dividingBy: 20)), width: 4, height: 6))
        }
    }
}
