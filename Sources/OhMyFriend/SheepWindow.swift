import AppKit
import CoreGraphics
import SceneKit

public protocol SheepWindowDelegate: AnyObject {
    func sheepWindowDidClick(_ window: SheepWindow)
}

public final class SheepWindow: EntityWindow {
    public private(set) var position: CGPoint
    public private(set) var hasWool: Bool = true
    public weak var sheepDelegate: SheepWindowDelegate?

    private var grazeTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var regrowTimer: TimeInterval = 0
    private let regrowDuration: TimeInterval = 60.0
    private let woolScale: CGFloat = 1.35
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var woolCap: SCNNode?

    public init(startPos: CGPoint, delegate: SheepWindowDelegate) {
        self.position = startPos
        self.sheepDelegate = delegate
        let size = NSSize(width: 72, height: 52)
        super.init(contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(bodyColor: .rgb(0.93, 0.93, 0.93), headColor: .rgb(0.80, 0.72, 0.66), legColor: .rgb(0.55, 0.42, 0.30))
        rig.body.scale = SCNVector3(woolScale, woolScale, woolScale)
        for leg in [rig.legFL, rig.legFR, rig.legBL, rig.legBR] {
            leg.scale = SCNVector3(1.0, 0.65, 1.0)
        }
        let cap = vbox(0.40, 0.15, 0.40, .rgb(0.93, 0.93, 0.93))
        cap.position = SCNVector3(0, 0.30, 0)
        rig.head.addChildNode(cap)
        self.woolCap = cap
        rig.scale = SCNVector3(0.8, 0.8, 0.8)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.sheepDelegate?.sheepWindowDidClick(self)
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        grazeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 30.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 36, y: self.position.y))
            if !self.hasWool {
                self.regrowTimer += 1.0 / 60.0
                if self.regrowTimer >= self.regrowDuration {
                    self.hasWool = true
                    self.regrowTimer = 0
                    self.rig?.body.scale = SCNVector3(self.woolScale, self.woolScale, self.woolScale)
                    self.woolCap?.isHidden = false
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = self.dir > 0 ? .pi / 2.0 : -.pi / 2.0
        }
        RunLoop.main.add(grazeTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        sheepDelegate?.sheepWindowDidClick(self)
    }

    public func shear() {
        hasWool = false
        regrowTimer = 0
        rig?.body.scale = SCNVector3(0.6, 0.6, 0.6)
        woolCap?.isHidden = true
    }

    public override func close() {
        grazeTimer?.invalidate()
        grazeTimer = nil
        super.close()
    }
}
