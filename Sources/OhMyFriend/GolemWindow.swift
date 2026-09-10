import AppKit
import CoreGraphics

public final class GolemWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var guardTimer: Timer?
    private var phase: TimeInterval = 0
    private var throwCooldown: TimeInterval = 0
    private let onThrow: (CGPoint) -> Void
    private var drawView: GolemDrawView?

    public init(startPos: CGPoint, onThrow: @escaping (CGPoint) -> Void) {
        self.anchor = startPos
        self.onThrow = onThrow
        let size = NSSize(width: 64, height: 92)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: true)
        let view = GolemDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        guardTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.throwCooldown -= 1.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.anchor.x - 32, y: self.anchor.y))
            self.drawView?.bob = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
            if self.throwCooldown <= 0 {
                self.throwCooldown = 3.0
                self.onThrow(CGPoint(x: self.anchor.x, y: self.anchor.y + 60))
            }
        }
        RunLoop.main.add(guardTimer!, forMode: .common)
    }

    public override func close() {
        guardTimer?.invalidate()
        guardTimer = nil
        super.close()
    }
}

private final class GolemDrawView: NSView {
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 4 + bob, width: 32, height: 24))
        ctx.fillEllipse(in: CGRect(x: 20, y: 26 + bob, width: 24, height: 20))
        ctx.setFillColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 46 + bob, width: 28, height: 20))
        ctx.setFillColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 25, y: 54 + bob, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: 35, y: 54 + bob, width: 5, height: 6))
        ctx.setFillColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 30 + bob, width: 12, height: 5))
        ctx.fill(CGRect(x: w - 16, y: 30 + bob, width: 12, height: 5))
    }
}
