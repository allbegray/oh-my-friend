import AppKit
import CoreGraphics
import SceneKit

public protocol PhantomWindowDelegate: AnyObject {
    func phantomWindowDidClick(_ window: PhantomWindow)
    func phantomWindowDidLeave(_ window: PhantomWindow)
    func phantomWindowDidDefeat(_ window: PhantomWindow)
}

public final class PhantomWindow: EntityWindow {
    public private(set) var position: CGPoint
    public var anchor: CGPoint = .zero
    public weak var phantomDelegate: PhantomWindowDelegate?

    private var hp = 2
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var swooping = false
    private var swoopTimer: TimeInterval = 2.5
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 12.0
    private var rig: FlyerRig?
    private var isGone = false

    public init(startPos: CGPoint, delegate: PhantomWindowDelegate) {
        self.position = startPos
        self.anchor = startPos
        self.phantomDelegate = delegate
        let size = NSSize(width: 84, height: 48)
        super.init(contentRect: NSRect(x: startPos.x - 42, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(
            bodyColor: .rgb(0.30, 0.48, 0.52),
            wingColor: .rgb(0.35, 0.55, 0.60)
        )
        rig.wingL.scale = SCNVector3(1.6, 1.4, 1.6)
        rig.wingR.scale = SCNVector3(1.6, 1.4, 1.6)
        for ex in [-0.08, 0.08] as [CGFloat] {
            let eye = vbox(0.06, 0.08, 0.02, .glow(0.95, 0.25, 0.35))
            eye.position = SCNVector3(ex, 0.05, 0.17)
            rig.body.addChildNode(eye)
        }
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.phantomDelegate?.phantomWindowDidClick(self)
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.lifeTimer += 1.0 / 60.0
            if self.lifeTimer >= self.maxLife {
                self.disappear(left: true)
                return
            }
            if !self.swooping {
                self.swoopTimer -= 1.0 / 60.0
                let cx = self.anchor.x + sin(self.phase * 0.9) * 150.0
                let cy = self.anchor.y + 120 + sin(self.phase * 1.7) * 24.0
                self.position = CGPoint(x: cx, y: cy)
                if self.swoopTimer <= 0 {
                    self.swooping = true
                    SoundAndEffectsManager.shared.play(.whoosh)
                }
            } else {
                let dx = self.anchor.x - self.position.x
                let dy = (self.anchor.y - 30) - self.position.y
                let dist = max(1, hypot(dx, dy))
                self.position.x += dx / dist * 330.0 / 60.0
                self.position.y += dy / dist * 330.0 / 60.0
                if dist < 40 {
                    self.swooping = false
                    self.swoopTimer = Double.random(in: 3.0...5.0)
                }
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - 42, y: self.position.y))
            self.rig?.flap(1.0 / 60.0)
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        phantomDelegate?.phantomWindowDidClick(self)
    }

    public func takeHit() {
        hp -= 1
        if hp <= 0 {
            disappear(left: false)
        } else {
            swooping = false
            swoopTimer = 2.0
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    public func disappear(left: Bool) {
        guard !isGone else { return }
        isGone = true
        flyTimer?.invalidate()
        flyTimer = nil
        if left {
            phantomDelegate?.phantomWindowDidLeave(self)
        } else {
            phantomDelegate?.phantomWindowDidDefeat(self)
        }
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class PhantomDrawView: NSView {
    var flap: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let wingSpread = 10 + flap * 6
        ctx.setFillColor(red: 0.35, green: 0.55, blue: 0.60, alpha: 0.95)
        ctx.fill(CGRect(x: 8, y: 0, width: 12, height: h - wingSpread))
        ctx.fill(CGRect(x: w - 20, y: 0, width: 12, height: h - wingSpread))
        ctx.setFillColor(red: 0.30, green: 0.48, blue: 0.52, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 12, y: 8, width: 24, height: 26))
        ctx.fill(CGRect(x: w / 2.0 - 10, y: 32, width: 20, height: 10))
        ctx.setFillColor(red: 0.95, green: 0.25, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 8, y: 22, width: 5, height: 7))
        ctx.fillEllipse(in: CGRect(x: w / 2.0 + 3, y: 22, width: 5, height: 7))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 6, y: 10, width: 12, height: 3))
    }
}
