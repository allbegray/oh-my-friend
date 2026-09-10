import AppKit
import CoreGraphics
import SceneKit

public final class GoatWindow: EntityWindow {
    public var targetX: CGFloat = 0
    private let onRam: () -> Void
    private let onMilk: () -> Void
    private var position: CGPoint
    private var aiTimer: Timer?
    private var phase: GoatPhase = .graze
    private var phaseTimer: TimeInterval = 3.0
    private var dir: CGFloat = 1
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var isAiming = false
    private var didHitThisCharge = false

    private enum GoatPhase {
        case graze
        case aim
        case charge
    }

    public init(startPos: CGPoint, onRam: @escaping () -> Void, onMilk: @escaping () -> Void) {
        self.position = startPos
        self.onRam = onRam
        self.onMilk = onMilk
        self.targetX = startPos.x
        let size = NSSize(width: 72, height: 56)
        super.init(contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(
            bodyColor: .rgb(0.90, 0.90, 0.86),
            headColor: .rgb(0.90, 0.90, 0.86),
            legColor: .rgb(0.90, 0.90, 0.86),
            tailColor: .rgb(0.90, 0.90, 0.86)
        )
        for x in [-0.16, 0.16] as [CGFloat] {
            let horn = vbox(0.08, 0.28, 0.08, .rgb(0.55, 0.42, 0.28))
            horn.position = SCNVector3(x, 0.34, -0.05)
            horn.eulerAngles.z = x > 0 ? -0.25 : 0.25
            rig.head.addChildNode(horn)
        }
        let beard = vbox(0.10, 0.16, 0.06, .rgb(0.75, 0.72, 0.68))
        beard.position = SCNVector3(0, -0.30, 0.15)
        rig.head.addChildNode(beard)
        let eyeL = vbox(0.05, 0.05, 0.02, .rgb(0.10, 0.10, 0.10))
        eyeL.position = SCNVector3(-0.12, 0.05, 0.25)
        rig.head.addChildNode(eyeL)
        let eyeR = vbox(0.05, 0.05, 0.02, .rgb(0.10, 0.10, 0.10))
        eyeR.position = SCNVector3(0.12, 0.05, 0.25)
        rig.head.addChildNode(eyeR)
        rig.addTo(view.scene!, scale: 1.0)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        aiTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phaseTimer -= 1.0 / 60.0
            switch self.phase {
            case .graze:
                if self.phaseTimer <= 0 {
                    self.phase = .aim
                    self.phaseTimer = 0.8
                    self.dir = self.targetX >= self.position.x ? 1 : -1
                    self.isAiming = true
                    self.rig?.head.eulerAngles.x = 0.35
                    SoundAndEffectsManager.shared.play(.alert)
                }
            case .aim:
                if self.phaseTimer <= 0 {
                    self.phase = .charge
                    self.phaseTimer = 1.2
                    self.didHitThisCharge = false
                }
            case .charge:
                self.position.x += self.dir * 380.0 / 60.0
                self.rig?.walk(1.0 / 60.0)
                self.rig?.walk(1.0 / 60.0)
                self.setFrameOrigin(NSPoint(x: self.position.x - 36, y: self.position.y))
                if !self.didHitThisCharge && abs(self.targetX - self.position.x) < 50 {
                    self.didHitThisCharge = true
                    self.onRam()
                }
                if self.phaseTimer <= 0 {
                    self.phase = .graze
                    self.phaseTimer = Double.random(in: 2.5...4.5)
                    self.isAiming = false
                    self.rig?.head.eulerAngles.x = 0
                }
            }
            if self.phase != .charge {
                self.rig?.walk(1.0 / 120.0)
            }
            self.rig?.eulerAngles.y = self.dir > 0 ? 0 : CGFloat.pi
        }
        RunLoop.main.add(aiTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onMilk()
    }

    public override func close() {
        aiTimer?.invalidate()
        aiTimer = nil
        super.close()
    }
}
