import AppKit
import CoreGraphics
import SceneKit

public final class AxolotlWindow: EntityWindow {
    private var followTimer: Timer?
    private var phase: TimeInterval = 0
    private var facingRight = true
    private var sceneView: MobSceneView?
    private var rig: QuadRig?

    public init() {
        let size = NSSize(width: 36, height: 28)
        super.init(contentRect: NSRect(x: 300, y: 300, width: size.width, height: size.height), ignoresMouse: true)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(bodyColor: .rgb(0.95, 0.55, 0.65), headColor: .rgb(0.95, 0.55, 0.65), legColor: .rgb(0.85, 0.40, 0.52), tailColor: .rgb(0.95, 0.55, 0.65))
        for (sx, sy) in [(-0.28, 0.10), (-0.28, -0.10), (0.28, 0.10), (0.28, -0.10)] as [(CGFloat, CGFloat)] {
            let gill = vbox(0.08, 0.15, 0.08, .rgb(1.0, 0.85, 0.30))
            gill.position = SCNVector3(sx, sy, 0.10)
            rig.head.addChildNode(gill)
        }
        rig.scale = SCNVector3(0.55, 0.55, 0.55)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func perch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        scheduleAutoDismiss(after: 15.0)
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 1.0 / 30.0
            self.rig?.walk(1.0 / 30.0)
            self.rig?.eulerAngles.z = sin(self.phase * 6.0) * 0.08
        }
        RunLoop.main.add(followTimer!, forMode: .common)
    }

    public func moveToShoulder(playerPos: CGPoint, facingRight: Bool) {
        let offsetX: CGFloat = facingRight ? -26 : 26
        setFrameOrigin(NSPoint(x: playerPos.x + offsetX - 18, y: playerPos.y + 52))
        self.facingRight = facingRight
        rig?.eulerAngles.y = facingRight ? .pi / 2.0 : -.pi / 2.0
    }

    public override func close() {
        followTimer?.invalidate()
        followTimer = nil
        super.close()
    }
}
