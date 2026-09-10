import AppKit
import CoreGraphics

public protocol PandaWindowDelegate: AnyObject {
    func pandaWindowDidClick(_ window: PandaWindow)
}

public final class PandaWindow: EntityWindow {
    public var position: CGPoint
    public var isBambooNearby: Bool = false
    public weak var pandaDelegate: PandaWindowDelegate?

    private var tickTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var sneezeCountdown: TimeInterval = 30
    private var sneezePhase: TimeInterval = -1
    private var hopVelocity: CGFloat = 0
    private var hopY: CGFloat = 0
    private var drawView: PandaDrawView?

    public init(startPos: CGPoint, delegate: PandaWindowDelegate) {
        self.position = startPos
        self.pandaDelegate = delegate
        let size = NSSize(width: 76, height: 60)
        super.init(contentRect: NSRect(x: startPos.x - 38, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = PandaDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
        resetSneezeCountdown()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 300 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            if self.isBambooNearby {
                self.position.x += self.dir * 40.0 / 60.0
                self.drawView?.rotation += self.dir * 0.12
            } else {
                self.position.x += self.dir * 25.0 / 60.0
                self.drawView?.rotation = 0
            }
            if self.sneezePhase >= 0 {
                self.sneezePhase += 1.0 / 60.0
                if self.sneezePhase > 0.8 {
                    self.sneezePhase = -1
                    self.drawView?.sneezeT = -1
                    self.resetSneezeCountdown()
                } else {
                    self.drawView?.sneezeT = self.sneezePhase
                }
            } else {
                self.sneezeCountdown -= 1.0 / 60.0
                if self.sneezeCountdown <= 0 {
                    self.fireSneeze()
                }
            }
            if self.hopY != 0 || self.hopVelocity != 0 {
                self.hopY += self.hopVelocity / 60.0
                self.hopVelocity -= 320.0 / 60.0
                if self.hopY <= 0 {
                    self.hopY = 0
                    self.hopVelocity = 0
                }
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - 38, y: self.position.y + self.hopY))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * 4.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tickTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        pandaDelegate?.pandaWindowDidClick(self)
    }

    public override func close() {
        tickTimer?.invalidate()
        tickTimer = nil
        super.close()
    }

    private func resetSneezeCountdown() {
        let extra = TimeInterval(arc4random_uniform(16))
        sneezeCountdown = 25.0 + extra
    }

    private func fireSneeze() {
        sneezePhase = 0
        drawView?.sneezeT = 0
        hopVelocity = 110
        hopY = 1
        SoundAndEffectsManager.shared.play(.pop)
        drawView?.needsDisplay = true
    }
}

private final class PandaDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0
    var rotation: CGFloat = 0
    var sneezeT: TimeInterval = -1

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.saveGState()
        ctx.translateBy(x: w / 2.0, y: 28 + bob)
        ctx.rotate(by: rotation)
        ctx.translateBy(x: -w / 2.0, y: -(28 + bob))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 14, y: 12 + bob, width: 48, height: 34))
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 38 + bob, width: 14, height: 14))
        ctx.fillEllipse(in: CGRect(x: 52, y: 38 + bob, width: 14, height: 14))
        ctx.fillEllipse(in: CGRect(x: 24, y: 26 + bob, width: 14, height: 16))
        ctx.fillEllipse(in: CGRect(x: 40, y: 26 + bob, width: 14, height: 16))
        ctx.fillEllipse(in: CGRect(x: 16, y: 2, width: 12, height: 12))
        ctx.fillEllipse(in: CGRect(x: 48, y: 2, width: 12, height: 12))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 27, y: 31 + bob, width: 4, height: 5))
        ctx.fillEllipse(in: CGRect(x: 43, y: 31 + bob, width: 4, height: 5))
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 35, y: 20 + bob, width: 8, height: 6))
        if sneezeT >= 0 {
            let a = max(0.0, 1.0 - CGFloat(sneezeT) / 0.8)
            ctx.setFillColor(red: 0.85, green: 0.95, blue: 1.0, alpha: a)
            for i in 0..<6 {
                let px = 60 + CGFloat(i * 5)
                let py = 30 + bob + CGFloat((i % 3) * 6) - CGFloat(sneezeT) * 20.0
                ctx.fillEllipse(in: CGRect(x: px, y: py, width: 4, height: 4))
            }
        }
        ctx.restoreGState()
        ctx.restoreGState()
    }
}
