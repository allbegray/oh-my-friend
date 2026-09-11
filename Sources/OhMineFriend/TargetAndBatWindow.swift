import AppKit
import CoreGraphics
import SceneKit

public final class TargetWindow: EntityWindow {
    public var centerPos: CGPoint = .zero

    public init(centerPos: CGPoint) {
        self.centerPos = centerPos
        let size = NSSize(width: 90, height: 90)
        super.init(contentRect: NSRect(
                x: centerPos.x - size.width / 2.0,
                y: centerPos.y - size.height / 2.0,
                width: size.width,
                height: size.height
            ), ignoresMouse: true)
        contentView = TargetDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        scheduleAutoDismiss(after: 12.0)
    }

    public func shake() {
        let orig = frame.origin
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.05
            self.animator().setFrameOrigin(NSPoint(x: orig.x + 5, y: orig.y))
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.05
                self.animator().setFrameOrigin(NSPoint(x: orig.x - 4, y: orig.y))
            }, completionHandler: {
                self.setFrameOrigin(orig)
            })
        })
    }
}

private final class TargetDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let c = CGPoint(x: w / 2.0, y: bounds.height / 2.0)
        let rings: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (40, 0.90, 0.90, 0.90), (31, 0.15, 0.15, 0.15),
            (22, 0.20, 0.55, 0.95), (13, 0.95, 0.20, 0.20), (5, 0.95, 0.85, 0.20),
        ]
        for (r, red, green, blue) in rings {
            ctx.setFillColor(red: red, green: green, blue: blue, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: 6, height: 18))
        ctx.fill(CGRect(x: w - 10, y: 0, width: 6, height: 18))
    }
}

