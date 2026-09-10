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

public final class BatWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var squeakTimer: TimeInterval = 6.0
    private let anchorProvider: () -> CGPoint
    private var rig: FlyerRig?

    public init(anchorProvider: @escaping () -> CGPoint) {
        self.anchorProvider = anchorProvider
        self.anchor = anchorProvider()
        let size = NSSize(width: 40, height: 30)
        super.init(contentRect: NSRect(x: anchor.x, y: anchor.y + 120, width: size.width, height: size.height), ignoresMouse: true)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(
            bodyColor: .rgb(0.25, 0.20, 0.28),
            wingColor: .rgb(0.25, 0.20, 0.28)
        )
        for x in [-0.10, 0.10] as [CGFloat] {
            let ear = vbox(0.10, 0.18, 0.06, .rgb(0.25, 0.20, 0.28))
            ear.position = SCNVector3(x, 0.30, 0)
            rig.body.addChildNode(ear)
        }
        for x in [-0.08, 0.08] as [CGFloat] {
            let eye = vbox(0.06, 0.08, 0.02, .glow(0.95, 0.20, 0.30))
            eye.position = SCNVector3(x, 0.05, 0.17)
            rig.body.addChildNode(eye)
        }
        rig.addTo(view.scene!, scale: 0.9)
        view.setSubject(rig)
        self.rig = rig
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.anchor = self.anchorProvider()
            let cx = self.anchor.x + cos(self.phase * 1.4) * 90.0
            let cy = self.anchor.y + 130 + sin(self.phase * 2.3) * 30.0
            self.setFrameOrigin(NSPoint(x: cx - 20, y: cy))
            self.rig?.flap(1.0 / 60.0)
            self.squeakTimer -= 1.0 / 60.0
            if self.squeakTimer <= 0 {
                self.squeakTimer = Double.random(in: 8.0...15.0)
                SoundAndEffectsManager.shared.play(.heart)
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
