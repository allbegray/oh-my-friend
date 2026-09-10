import AppKit
import CoreGraphics

public final class WitchWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var hp = 2
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var throwTimer: TimeInterval = 5.0
    private let onThrow: () -> Void
    private let onDefeat: () -> Void
    private var drawView: WitchDrawView?
    private var isGone = false

    public init(startPos: CGPoint, onThrow: @escaping () -> Void, onDefeat: @escaping () -> Void) {
        self.anchor = startPos
        self.onThrow = onThrow
        self.onDefeat = onDefeat
        let size = NSSize(width: 56, height: 84)
        super.init(contentRect: NSRect(x: startPos.x - 28, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = WitchDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.throwTimer -= 1.0 / 60.0
            let cy = self.anchor.y + 60 + sin(self.phase * 1.3) * 14.0
            self.setFrameOrigin(NSPoint(x: self.anchor.x - 28, y: cy))
            self.drawView?.bob = sin(self.phase * 5.0)
            self.drawView?.needsDisplay = true
            if self.throwTimer <= 0 {
                self.throwTimer = Double.random(in: 6.0...9.0)
                self.onThrow()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        hp -= 1
        if hp <= 0 {
            guard !isGone else { return }
            isGone = true
            flyTimer?.invalidate()
            flyTimer = nil
            onDefeat()
            close()
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    public func dismiss() {
        guard !isGone else { return }
        isGone = true
        flyTimer?.invalidate()
        flyTimer = nil
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class WitchDrawView: NSView {
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.25, green: 0.12, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 10 + bob, width: 28, height: 34))
        ctx.setFillColor(red: 0.55, green: 0.75, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 44 + bob, width: 20, height: 14))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 23, y: 50 + bob, width: 4, height: 5))
        ctx.fillEllipse(in: CGRect(x: 31, y: 50 + bob, width: 4, height: 5))
        ctx.setFillColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 1.0)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w / 2.0 - 16, y: 58 + bob))
        ctx.addLine(to: CGPoint(x: w / 2.0 + 16, y: 58 + bob))
        ctx.addLine(to: CGPoint(x: w / 2.0, y: 80 + bob))
        ctx.closePath()
        ctx.fillPath()
        ctx.setFillColor(red: 0.35, green: 0.85, blue: 0.35, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: w - 18, y: 20 + bob, width: 8, height: 10))
    }
}
