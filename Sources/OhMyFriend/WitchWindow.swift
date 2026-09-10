import AppKit
import CoreGraphics
import SceneKit

public final class WitchWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var hp = 2
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var throwTimer: TimeInterval = 5.0
    private let onThrow: () -> Void
    private let onDefeat: () -> Void
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var isGone = false

    public init(startPos: CGPoint, onThrow: @escaping () -> Void, onDefeat: @escaping () -> Void) {
        self.anchor = startPos
        self.onThrow = onThrow
        self.onDefeat = onDefeat
        let size = NSSize(width: 56, height: 84)
        super.init(contentRect: NSRect(x: startPos.x - 28, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let robe = VoxelColor.rgb(0.25, 0.12, 0.35)
        let robeDark = VoxelColor.rgb(0.15, 0.08, 0.25)
        let skin = VoxelColor.rgb(0.55, 0.75, 0.55)
        let r = BipedRig(headColor: skin, torsoColor: robe, limbColor: robeDark)
        r.torso.scale.y = 1.25
        let nose = vbox(0.10, 0.12, 0.10, VoxelColor.rgb(0.35, 0.85, 0.35))
        nose.position = SCNVector3(0, -0.05, 0.28)
        r.head.addChildNode(nose)
        let socket = VoxelColor.rgb(0.10, 0.10, 0.10)
        let eyeL = vbox(0.07, 0.08, 0.02, socket)
        eyeL.position = SCNVector3(-0.10, 0.08, 0.26)
        r.head.addChildNode(eyeL)
        let eyeR = vbox(0.07, 0.08, 0.02, socket)
        eyeR.position = SCNVector3(0.10, 0.08, 0.26)
        r.head.addChildNode(eyeR)
        let brim = vbox(0.64, 0.06, 0.64, robeDark)
        brim.position = SCNVector3(0, 0.28, 0)
        r.head.addChildNode(brim)
        let cone = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.24, height: 0.45))
        cone.geometry?.materials = [voxelMaterial(robeDark)]
        cone.position = SCNVector3(0, 0.52, 0)
        r.head.addChildNode(cone)
        let potion = vbox(0.10, 0.14, 0.10, VoxelColor.glow(0.35, 0.85, 0.35))
        potion.position = SCNVector3(0, -0.70, 0.06)
        r.armR.addChildNode(potion)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in self?.hit() }
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
            self.rig?.walk(1.0 / 60.0)
            self.rig?.position.y = CGFloat(sin(self.phase * 5.0)) * 0.05
            if self.throwTimer <= 0 {
                self.throwTimer = Double.random(in: 6.0...9.0)
                self.onThrow()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        hit()
    }

    private func hit() {
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
