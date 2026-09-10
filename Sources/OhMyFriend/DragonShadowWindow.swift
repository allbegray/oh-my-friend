import AppKit
import CoreGraphics

public final class DragonShadowWindow: EntityWindow {
    private var flyTimer: Timer?
    private var progress: CGFloat = 0
    private let duration: TimeInterval = 6.0
    private var drawView: DragonShadowDrawView?

    public init(screen: NSScreen) {
        let h: CGFloat = 130
        super.init(contentRect: NSRect(x: screen.frame.minX, y: screen.frame.maxY - h - 30, width: screen.frame.width, height: h), ignoresMouse: true)
        let view = DragonShadowDrawView(frame: NSRect(origin: .zero, size: NSSize(width: screen.frame.width, height: h)))
        self.drawView = view
        contentView = view
    }

    public func flyby() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        let start = ProcessInfo.processInfo.systemUptime
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            self.progress = min(1.0, CGFloat(elapsed / self.duration))
            self.drawView?.progress = self.progress
            self.drawView?.needsDisplay = true
            if self.progress >= 1.0 {
                t.invalidate()
                self.flyTimer = nil
                self.close()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class DragonShadowDrawView: NSView {
    var progress: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let x = w * progress
        let alpha = sin(progress * CGFloat.pi)
        ctx.setFillColor(red: 0.05, green: 0.02, blue: 0.10, alpha: 0.55 * alpha)
        ctx.saveGState()
        ctx.translateBy(x: x, y: h / 2)
        let s: CGFloat = 1.6
        ctx.scaleBy(x: s, y: s)
        ctx.fillEllipse(in: CGRect(x: -28, y: -8, width: 56, height: 16))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: -28, y: 0))
        ctx.addLine(to: CGPoint(x: -52, y: 20))
        ctx.addLine(to: CGPoint(x: -30, y: 2))
        ctx.closePath()
        ctx.fillPath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 28, y: 0))
        ctx.addLine(to: CGPoint(x: 52, y: 20))
        ctx.addLine(to: CGPoint(x: 30, y: 2))
        ctx.closePath()
        ctx.fillPath()
        ctx.fill(CGRect(x: 28, y: -3, width: 22, height: 6))
        ctx.restoreGState()
    }
}
