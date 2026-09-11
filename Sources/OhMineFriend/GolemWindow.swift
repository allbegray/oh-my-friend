import AppKit
import CoreGraphics
import SceneKit

public final class GolemWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var guardTimer: Timer?
    private var phase: TimeInterval = 0
    private var throwCooldown: TimeInterval = 0
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 12.0
    private let onThrow: (CGPoint) -> Void
    private var sceneView: MobSceneView?
    private var rig: BipedRig?

    public init(startPos: CGPoint, onThrow: @escaping (CGPoint) -> Void) {
        self.anchor = startPos
        self.onThrow = onThrow
        let size = NSSize(width: 64, height: 92)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: true)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = BipedRig(headColor: .rgb(0.95, 0.55, 0.10), torsoColor: .rgb(0.94, 0.94, 0.96), limbColor: .rgb(0.55, 0.35, 0.18))
        let mid = vbox(0.50, 0.35, 0.30, .rgb(0.94, 0.94, 0.96))
        mid.position = SCNVector3(0, -0.55, 0)
        rig.torso.addChildNode(mid)
        let base = vbox(0.62, 0.40, 0.36, .rgb(0.94, 0.94, 0.96))
        base.position = SCNVector3(0, -0.95, 0)
        rig.torso.addChildNode(base)
        for sx in [-0.12, 0.12] as [CGFloat] {
            let eye = vbox(0.08, 0.10, 0.04, .rgb(0.15, 0.12, 0.10))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            rig.head.addChildNode(eye)
        }
        rig.scale = SCNVector3(0.8, 0.8, 0.8)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        guardTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.lifeTimer += 1.0 / 60.0
            if self.lifeTimer >= self.maxLife {
                self.close()
                return
            }
            self.throwCooldown -= 1.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.anchor.x - 32, y: self.anchor.y))
            self.rig?.walk(1.0 / 60.0)
            if self.throwCooldown <= 0 {
                self.throwCooldown = 2.0
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
