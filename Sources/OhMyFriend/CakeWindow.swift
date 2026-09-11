import AppKit
import CoreGraphics

public final class CakeWindow: EntityWindow {
    public let floorPos: CGPoint
    public var slicesCount: Int { slicesLeft }
    private let onSlice: () -> Void
    private var slicesLeft = 7
    private var drawView: CakeDrawView?

    public init(floorPos: CGPoint, onSlice: @escaping () -> Void) {
        self.floorPos = floorPos
        self.onSlice = onSlice
        let size = NSSize(width: 84, height: 56)
        super.init(contentRect: NSRect(
                x: floorPos.x - size.width / 2.0,
                y: floorPos.y,
                width: size.width,
                height: size.height
            ), ignoresMouse: false)
        let view = CakeDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        scheduleAutoDismiss(after: 14.0)
    }

    public func eatSlice() {
        guard slicesLeft > 0 else { return }
        slicesLeft -= 1
        drawView?.slicesLeft = slicesLeft
        drawView?.needsDisplay = true
        onSlice()
        if slicesLeft <= 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.close()
            }
        }
    }

    public override func mouseDown(with event: NSEvent) {
        eatSlice()
    }
}

private final class CakeDrawView: NSView {
    var slicesLeft = 7

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.80, green: 0.80, blue: 0.82, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 2, width: w - 12, height: 14))
        if slicesLeft <= 0 {
            return
        }
        let frac = CGFloat(slicesLeft) / 7.0
        let cakeW = (w - 12) * frac
        ctx.setFillColor(red: 0.72, green: 0.45, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 12, width: cakeW, height: 20))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 28, width: cakeW, height: 8))
        ctx.setFillColor(red: 0.90, green: 0.15, blue: 0.20, alpha: 1.0)
        let cherries = min(slicesLeft, 4)
        for i in 0..<cherries {
            let x = 12 + CGFloat(i) * 16 * frac + 8 * (1 - frac)
            ctx.fillEllipse(in: CGRect(x: min(x, w - 18), y: 38, width: 7, height: 7))
        }
    }
}
