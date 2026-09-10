import AppKit
import CoreGraphics
import SceneKit

public protocol MooshroomWindowDelegate: AnyObject {
    func mooshroomWindowDidClick(_ window: MooshroomWindow)
}

public final class MooshroomWindow: EntityWindow {
    public private(set) var position: CGPoint
    public weak var mooshroomDelegate: MooshroomWindowDelegate?

    private var wanderTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var mooCooldown: TimeInterval = 6.0
    private var mooFlash: TimeInterval = 0
    private var heartFlash: TimeInterval = 0
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var mooNode: SCNNode?
    private var heartNode: SCNNode?

    public init(startPos: CGPoint, delegate: MooshroomWindowDelegate) {
        self.position = startPos
        self.mooshroomDelegate = delegate
        let size = NSSize(width: 84, height: 60)
        super.init(contentRect: NSRect(x: startPos.x - 42, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let red = VoxelColor.rgb(0.78, 0.18, 0.16)
        let darkRed = VoxelColor.rgb(0.62, 0.14, 0.12)
        let white = VoxelColor.rgb(0.95, 0.95, 0.95)
        let r = QuadRig(bodyColor: red, headColor: red, legColor: darkRed, tailColor: nil)
        let spot1 = vbox(0.18, 0.02, 0.14, white)
        spot1.position = SCNVector3(-0.10, 0.26, 0.10)
        r.body.addChildNode(spot1)
        let spot2 = vbox(0.14, 0.02, 0.14, white)
        spot2.position = SCNVector3(0.14, 0.26, -0.12)
        r.body.addChildNode(spot2)
        let headSpot = vbox(0.12, 0.10, 0.02, white)
        headSpot.position = SCNVector3(-0.08, 0.10, 0.25)
        r.head.addChildNode(headSpot)
        let socket = VoxelColor.rgb(0.08, 0.08, 0.08)
        let eye = vbox(0.06, 0.08, 0.02, socket)
        eye.position = SCNVector3(0.12, 0.05, 0.25)
        r.head.addChildNode(eye)
        let snout = vbox(0.20, 0.10, 0.08, VoxelColor.rgb(0.93, 0.80, 0.78))
        snout.position = SCNVector3(0, -0.14, 0.26)
        r.head.addChildNode(snout)
        for dx in [-0.12, 0.12] as [CGFloat] {
            let stem = vbox(0.08, 0.10, 0.08, white)
            stem.position = SCNVector3(dx, 0.30, 0)
            r.body.addChildNode(stem)
            let cap = vbox(0.22, 0.10, 0.22, VoxelColor.rgb(0.85, 0.20, 0.18))
            cap.position = SCNVector3(dx, 0.39, 0)
            r.body.addChildNode(cap)
            let dot = vbox(0.06, 0.03, 0.06, VoxelColor.rgb(1.0, 1.0, 1.0))
            dot.position = SCNVector3(dx + 0.04, 0.45, 0.04)
            r.body.addChildNode(dot)
        }
        let moo = vbox(0.12, 0.12, 0.12, VoxelColor.glow(1.0, 1.0, 1.0))
        moo.position = SCNVector3(0.20, 0.45, 0.10)
        r.head.addChildNode(moo)
        moo.isHidden = true
        self.mooNode = moo
        let heart = vbox(0.12, 0.12, 0.12, VoxelColor.glow(1.0, 0.30, 0.45))
        heart.position = SCNVector3(0, 0.65, 0)
        r.body.addChildNode(heart)
        heart.isHidden = true
        self.heartNode = heart
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.mooshroomDelegate?.mooshroomWindowDidClick(self)
        }
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.mooCooldown -= 1.0 / 60.0
            if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 300 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            if self.mooCooldown <= 0 {
                self.mooCooldown = Double.random(in: 8.0...16.0)
                self.mooFlash = 0.8
            }
            self.position.x += self.dir * 20.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 42, y: self.position.y))
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = CGFloat(self.dir > 0 ? Double.pi / 2.0 : -Double.pi / 2.0)
            if self.mooFlash > 0 {
                self.mooFlash -= 1.0 / 60.0
            }
            if self.heartFlash > 0 {
                self.heartFlash -= 1.0 / 60.0
                let rise = CGFloat(1.2 - self.heartFlash) * 0.15
                self.heartNode?.position.y = 0.65 + rise
            }
            self.mooNode?.isHidden = self.mooFlash <= 0
            self.heartNode?.isHidden = self.heartFlash <= 0
        }
        RunLoop.main.add(wanderTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        mooshroomDelegate?.mooshroomWindowDidClick(self)
    }

    /// 빈 양동이(HeldItem.emptyBucket)를 든 상태에서 클릭 시 AppController 콜백에서 호출.
    /// 스튜 획득 연출: 꿀꺽 사운드 + 하트 파티클.
    public func collectStew() {
        SoundAndEffectsManager.shared.play(.gulp)
        heartFlash = 1.2
        heartNode?.isHidden = false
    }

    public override func close() {
        wanderTimer?.invalidate()
        wanderTimer = nil
        super.close()
    }
}
