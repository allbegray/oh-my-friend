import AppKit
import CoreGraphics
import SceneKit

public protocol ChickenWindowDelegate: AnyObject {
    func chickenWindowDidClick(_ window: ChickenWindow)
    func chickenWindowDidHatchChick(_ parent: ChickenWindow, chick: ChickenWindow)
}

public extension ChickenWindowDelegate {
    func chickenWindowDidClick(_ window: ChickenWindow) {}
    func chickenWindowDidHatchChick(_ parent: ChickenWindow, chick: ChickenWindow) {}
}

public final class ChickenWindow: EntityWindow {
    public var position: CGPoint
    public let scale: CGFloat
    public weak var chickenDelegate: ChickenWindowDelegate?

    private var wanderTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var layTimer: TimeInterval = 0
    private let layInterval: TimeInterval = 5.0
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 12.0
    private let maxEggs = 3
    private var eggs: [EggWindow] = []
    private var chicks: [ChickenWindow] = []
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var panelW: CGFloat = 60
    private var panelH: CGFloat = 48

    public init(startPos: CGPoint, delegate: ChickenWindowDelegate, scale: CGFloat = 1.0) {
        self.position = startPos
        self.scale = scale
        self.chickenDelegate = delegate
        let w: CGFloat = 60 * scale
        let h: CGFloat = 48 * scale
        self.panelW = w
        self.panelH = h
        super.init(contentRect: NSRect(x: startPos.x - w / 2.0, y: startPos.y, width: w, height: h), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)))
        let white = VoxelColor.rgb(0.96, 0.96, 0.96)
        let wingGray = VoxelColor.rgb(0.85, 0.85, 0.87)
        let orange = VoxelColor.rgb(0.95, 0.55, 0.15)
        let r = BipedRig(headColor: white, torsoColor: white, limbColor: orange)
        for arm in [r.armL, r.armR] {
            for mesh in arm.childNodes {
                mesh.geometry?.materials = [voxelMaterial(wingGray)]
            }
        }
        let comb = VoxelColor.rgb(0.90, 0.12, 0.15)
        for (i, dx) in ([-0.10, 0.0, 0.10] as [CGFloat]).enumerated() {
            let c = vbox(0.09, i == 1 ? 0.16 : 0.12, 0.09, comb)
            c.position = SCNVector3(dx, 0.32, 0)
            r.head.addChildNode(c)
        }
        let beak = vbox(0.14, 0.09, 0.10, VoxelColor.rgb(1.0, 0.65, 0.10))
        beak.position = SCNVector3(0, -0.02, 0.29)
        r.head.addChildNode(beak)
        let socket = VoxelColor.rgb(0.08, 0.08, 0.08)
        let eyeL = vbox(0.06, 0.08, 0.02, socket)
        eyeL.position = SCNVector3(-0.13, 0.06, 0.26)
        r.head.addChildNode(eyeL)
        let eyeR = vbox(0.06, 0.08, 0.02, socket)
        eyeR.position = SCNVector3(0.13, 0.06, 0.26)
        r.head.addChildNode(eyeR)
        if let scn = view.scene {
            r.addTo(scn, scale: scale)
        }
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.chickenDelegate?.chickenWindowDidClick(self)
        }
        contentView = view
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.lifeTimer += 1.0 / 60.0
            if self.lifeTimer >= self.maxLife {
                self.close()
                return
            }
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 30.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2.0, y: self.position.y))
            if self.scale >= 1.0 {
                self.layTimer += 1.0 / 60.0
                if self.layTimer >= self.layInterval {
                    self.layTimer = 0
                    self.layEgg()
                }
            }
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = CGFloat(self.dir > 0 ? Double.pi / 2.0 : -Double.pi / 2.0)
            self.rig?.position.y = CGFloat(sin(self.phase * 6.0)) * 0.03
        }
        RunLoop.main.add(wanderTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        chickenDelegate?.chickenWindowDidClick(self)
    }

    public override func close() {
        wanderTimer?.invalidate()
        wanderTimer = nil
        for egg in eggs {
            egg.close()
        }
        eggs.removeAll()
        for chick in chicks {
            chick.close()
        }
        chicks.removeAll()
        super.close()
    }

    public func layEgg() {
        eggs = eggs.filter { $0.isVisible }
        guard eggs.count < maxEggs else { return }
        let eggPos = CGPoint(x: position.x + CGFloat.random(in: -12...12), y: position.y - 4)
        let egg = EggWindow(floorPos: eggPos) { [weak self] tapped in
            self?.handleEggClicked(tapped)
        }
        eggs.append(egg)
        egg.place()
    }

    public func handleEggClicked(_ egg: EggWindow) {
        let eggPos = egg.position
        eggs.removeAll { $0 === egg }
        egg.close()
        if Double.random(in: 0..<1) < 0.3 {
            guard let delegate = chickenDelegate else { return }
            let chick = ChickenWindow(startPos: eggPos, delegate: delegate, scale: 0.5)
            chicks.append(chick)
            chick.start()
            chickenDelegate?.chickenWindowDidHatchChick(self, chick: chick)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }
}

public final class EggWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (EggWindow) -> Void
    private var drawView: EggDrawView?

    public init(floorPos: CGPoint, onTap: @escaping (EggWindow) -> Void) {
        self.position = floorPos
        self.onTap = onTap
        let size = NSSize(width: 24, height: 28)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = EggDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        scheduleAutoDismiss(after: 8.0) { [weak self] in
            guard let self = self else { return }
            self.onTap(self)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        super.close()
    }
}

private final class EggDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 알 몸통 (크림색 타원)
        ctx.setFillColor(red: 0.97, green: 0.94, blue: 0.86, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 3, y: 2, width: 18, height: 24))
        // 광택 하이라이트
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
        ctx.fillEllipse(in: CGRect(x: 7, y: 16, width: 5, height: 7))
        // 얼룩 점 2개
        ctx.setFillColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 8, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 9, y: 12, width: 3, height: 3))
    }
}
