import AppKit
import CoreGraphics

public final class RainOverlayWindow: EntityWindow {
    private var rainTimer: Timer?
    private var drops: [CGPoint] = []
    private var drawView: RainDrawView?
    private var flashAlpha: CGFloat = 0
    private var boltX: CGFloat = 0

    public init(screen: NSScreen) {
        super.init(contentRect: screen.frame, ignoresMouse: true, level: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) - 2))
        self.autoDismissDuration = 0
        let view = RainDrawView(frame: NSRect(origin: .zero, size: screen.frame.size))
        self.drawView = view
        contentView = view
        for _ in 0..<140 {
            drops.append(CGPoint(
                x: CGFloat.random(in: 0...screen.frame.width),
                y: CGFloat.random(in: 0...screen.frame.height)
            ))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        orderFrontRegardless()
        guard rainTimer == nil else { return }
        rainTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self, let view = self.drawView else { t.invalidate(); return }
            let h = view.bounds.height
            let w = view.bounds.width
            for i in self.drops.indices {
                self.drops[i].y -= 22
                self.drops[i].x -= 3
                if self.drops[i].y < 0 {
                    self.drops[i] = CGPoint(x: CGFloat.random(in: 0...w), y: h)
                }
            }
            if self.flashAlpha > 0 {
                self.flashAlpha = max(0, self.flashAlpha - 0.08)
            }
            view.drops = self.drops
            view.flashAlpha = self.flashAlpha
            view.needsDisplay = true
        }
        RunLoop.main.add(rainTimer!, forMode: .common)
    }

    public func flashLightning() {
        guard let view = drawView else { return }
        flashAlpha = 0.55
        boltX = CGFloat.random(in: view.bounds.width * 0.2...view.bounds.width * 0.8)
        view.boltX = boltX
        view.flashAlpha = flashAlpha
        SoundAndEffectsManager.shared.play(.explode)
    }

    public func hide() {
        rainTimer?.invalidate()
        rainTimer = nil
        orderOut(nil)
    }
}

private final class RainDrawView: NSView {
    var drops: [CGPoint] = []
    var flashAlpha: CGFloat = 0
    var boltX: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setStrokeColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 0.45)
        ctx.setLineWidth(1.5)
        for d in drops {
            ctx.beginPath()
            ctx.move(to: d)
            ctx.addLine(to: CGPoint(x: d.x + 3, y: d.y + 14))
            ctx.strokePath()
        }
        if flashAlpha > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: flashAlpha)
            ctx.fill(bounds)
            ctx.setStrokeColor(red: 1.0, green: 0.95, blue: 0.6, alpha: min(1.0, flashAlpha + 0.3))
            ctx.setLineWidth(4)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: boltX, y: bounds.height))
            ctx.addLine(to: CGPoint(x: boltX - 18, y: bounds.height * 0.66))
            ctx.addLine(to: CGPoint(x: boltX + 6, y: bounds.height * 0.33))
            ctx.addLine(to: CGPoint(x: boltX - 10, y: 0))
            ctx.strokePath()
        }
    }
}
