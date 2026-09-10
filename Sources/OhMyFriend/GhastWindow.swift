import AppKit
import CoreGraphics
import SceneKit

public protocol GhastWindowDelegate: AnyObject {
    func ghastDidDefeat(_ window: GhastWindow)
    func ghastDidLeave(_ window: GhastWindow)
}

public final class GhastWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    public weak var ghastDelegate: GhastWindowDelegate?

    private var hp = 3
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var shootTimer: TimeInterval = 5.0
    private let onShoot: (CGPoint) -> Void
    private var sceneView: MobSceneView?
    private var rig: FlyerRig?
    private var mouthNode: SCNNode?
    private var isGone = false

    public init(startPos: CGPoint, delegate: GhastWindowDelegate, onShoot: @escaping (CGPoint) -> Void) {
        self.anchor = startPos
        self.ghastDelegate = delegate
        self.onShoot = onShoot
        let size = NSSize(width: 110, height: 90)
        super.init(contentRect: NSRect(x: startPos.x - 55, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(bodyColor: .rgb(0.94, 0.94, 0.94), wingColor: .rgb(0.94, 0.94, 0.94))
        // 대형 흰 몸통 (기존 2D 흰 사각 몸통 유지)
        let bulk = vbox(1.15, 0.95, 0.95, .rgb(0.94, 0.94, 0.94))
        rig.body.addChildNode(bulk)
        // 촉수 느낌 아래 박스 4개
        for i in 0..<4 {
            let t = vbox(0.14, 0.50, 0.14, .rgb(0.94, 0.94, 0.94))
            t.position = SCNVector3(-0.42 + CGFloat(i) * 0.28, -0.65, 0)
            rig.body.addChildNode(t)
        }
        // 검은 눈 + 눈물 자국
        for sx in [-0.28, 0.28] as [CGFloat] {
            let eye = vbox(0.14, 0.18, 0.05, .rgb(0.10, 0.10, 0.12))
            eye.position = SCNVector3(sx, 0.18, 0.50)
            rig.body.addChildNode(eye)
            let tear = vbox(0.07, 0.30, 0.04, .rgb(0.10, 0.10, 0.12))
            tear.position = SCNVector3(sx, -0.08, 0.50)
            rig.body.addChildNode(tear)
        }
        // 입 (발사 직전 벌어짐)
        let mouth = vbox(0.30, 0.26, 0.05, .rgb(0.75, 0.10, 0.10))
        mouth.position = SCNVector3(0, -0.22, 0.50)
        mouth.isHidden = true
        rig.body.addChildNode(mouth)
        self.mouthNode = mouth
        rig.scale = SCNVector3(0.85, 0.85, 0.85)
        view.setSubject(rig)
        self.rig = rig
        self.sceneView = view
        view.onTap = { [weak self] in self?.registerHit() }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.portal)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.shootTimer -= 1.0 / 60.0
            let cx = self.anchor.x + sin(self.phase * 0.7) * 90.0
            let cy = self.anchor.y + 130 + sin(self.phase * 1.1) * 20.0
            self.setFrameOrigin(NSPoint(x: cx - 55, y: cy))
            self.rig?.flap(1.0 / 60.0)
            self.mouthNode?.isHidden = self.shootTimer >= 0.8
            if self.shootTimer <= 0 {
                self.shootTimer = Double.random(in: 4.0...6.5)
                self.onShoot(CGPoint(x: cx, y: cy))
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public var centerPos: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    public override func mouseDown(with event: NSEvent) {
        registerHit()
    }

    private func registerHit() {
        hp -= 1
        if hp <= 0 {
            disappear(defeated: true)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        flyTimer?.invalidate()
        flyTimer = nil
        if defeated {
            ghastDelegate?.ghastDidDefeat(self)
        } else {
            ghastDelegate?.ghastDidLeave(self)
        }
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

public final class FireballWindow: EntityWindow {
    private let from: CGPoint
    private let target: CGPoint
    private let onArrive: (Bool) -> Void
    private var flyTimer: Timer?
    private var progress: CGFloat = 0

    public init(from: CGPoint, target: CGPoint, onArrive: @escaping (Bool) -> Void) {
        self.from = from
        self.target = target
        self.onArrive = onArrive
        let size: CGFloat = 34.0
        super.init(contentRect: NSRect(x: from.x - 17, y: from.y - 17, width: size, height: size), ignoresMouse: false)
        contentView = FireballDrawView(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
    }

    public func launch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.ignite)
        let distance = hypot(target.x - from.x, target.y - from.y)
        let flightTime = max(0.5, Double(distance / 420.0))
        let startTime = ProcessInfo.processInfo.systemUptime
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let p = min(1.0, CGFloat(elapsed / flightTime))
            let curX = self.from.x + (self.target.x - self.from.x) * p
            let curY = self.from.y + (self.target.y - self.from.y) * p
            self.setFrameOrigin(NSPoint(x: curX - 17, y: curY - 17))
            if p >= 1.0 {
                t.invalidate()
                self.flyTimer = nil
                self.onArrive(true)
                self.close()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        flyTimer?.invalidate()
        flyTimer = nil
        onArrive(false)
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class FireballDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = bounds.width
        ctx.setFillColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: s - 8, height: s - 8))
        ctx.setFillColor(red: 1.0, green: 0.90, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 10, width: s - 20, height: s - 20))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 14, y: 14, width: s - 28, height: s - 28))
    }
}
