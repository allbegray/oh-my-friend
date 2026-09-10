import AppKit
import CoreGraphics
import SceneKit

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
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var roll: CGFloat = 0
    private var facingRight = true
    private var sneezeT: TimeInterval = -1

    public init(startPos: CGPoint, delegate: PandaWindowDelegate) {
        self.position = startPos
        self.pandaDelegate = delegate
        let size = NSSize(width: 76, height: 60)
        super.init(contentRect: NSRect(x: startPos.x - 38, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(
            bodyColor: .rgb(1.0, 1.0, 1.0),
            headColor: .rgb(1.0, 1.0, 1.0),
            legColor: .rgb(0.12, 0.12, 0.12),
            tailColor: nil
        )
        for x in [-0.13, 0.13] as [CGFloat] {
            let patch = vbox(0.14, 0.16, 0.02, .rgb(0.12, 0.12, 0.12))
            patch.position = SCNVector3(x, 0.03, 0.25)
            rig.head.addChildNode(patch)
            let glint = vbox(0.04, 0.05, 0.025, .rgb(1.0, 1.0, 1.0))
            glint.position = SCNVector3(x + 0.03, 0.06, 0.25)
            rig.head.addChildNode(glint)
        }
        for x in [-0.16, 0.16] as [CGFloat] {
            let ear = vbox(0.14, 0.14, 0.10, .rgb(0.12, 0.12, 0.12))
            ear.position = SCNVector3(x, 0.30, 0)
            rig.head.addChildNode(ear)
        }
        let nose = vbox(0.08, 0.06, 0.02, .rgb(0.12, 0.12, 0.12))
        nose.position = SCNVector3(0, -0.08, 0.25)
        rig.head.addChildNode(nose)
        rig.addTo(view.scene!, scale: 1.0)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
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
                self.roll += self.dir * 0.12
                self.rig?.walk(1.0 / 60.0)
            } else {
                self.position.x += self.dir * 25.0 / 60.0
                self.roll = 0
                self.rig?.walk(1.0 / 60.0)
            }
            self.rig?.eulerAngles.z = self.roll
            self.rig?.eulerAngles.y = self.dir > 0 ? 0 : CGFloat.pi
            if self.sneezePhase >= 0 {
                self.sneezePhase += 1.0 / 60.0
                if self.sneezePhase > 0.8 {
                    self.sneezePhase = -1
                    self.sneezeT = -1
                    self.resetSneezeCountdown()
                } else {
                    self.sneezeT = self.sneezePhase
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
            self.facingRight = self.dir > 0
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
        sneezeT = 0
        hopVelocity = 110
        hopY = 1
        SoundAndEffectsManager.shared.play(.pop)
    }
}
