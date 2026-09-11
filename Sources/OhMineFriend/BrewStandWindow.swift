import AppKit
import CoreGraphics

public final class BrewStandWindow: EntityWindow {
    private let onBrew: () -> Void

    public init(floorPos: CGPoint, onBrew: @escaping () -> Void) {
        self.onBrew = onBrew
        let size = NSSize(width: 72, height: 80)
        super.init(contentRect: NSRect(
            x: floorPos.x - size.width / 2.0,
            y: floorPos.y,
            width: size.width,
            height: size.height
        ), ignoresMouse: false)
        contentView = BrewStandDrawView(frame: NSRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        scheduleAutoDismiss(after: 14.0)
    }

    public override func mouseDown(with event: NSEvent) {
        onBrew()
    }
}

private final class BrewStandDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.30, green: 0.28, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 8))
        ctx.fill(CGRect(x: w / 2.0 - 3, y: 8, width: 6, height: 26))
        ctx.setFillColor(red: 0.45, green: 0.40, blue: 0.48, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 30, width: w - 24, height: 6))
        let bottleColors = [
            (0.95, 0.25, 0.30), (0.35, 0.75, 0.95), (0.95, 0.75, 0.20),
        ]
        for (i, c) in bottleColors.enumerated() {
            let x = 16 + CGFloat(i) * 16
            ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 0.9)
            ctx.fill(CGRect(x: x, y: 36, width: 10, height: 16))
            ctx.setFillColor(red: 0.8, green: 0.75, blue: 0.65, alpha: 1.0)
            ctx.fill(CGRect(x: x + 2, y: 52, width: 6, height: 5))
        }
        ctx.setFillColor(red: 0.70, green: 0.40, blue: 0.95, alpha: 0.5)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 3, y: 60, width: 6, height: 8))
    }
}
