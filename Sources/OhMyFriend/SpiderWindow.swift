import AppKit
import CoreGraphics
import SceneKit

public protocol SpiderWindowDelegate: AnyObject {
    func spiderWindowDidClick(_ window: SpiderWindow)
    func spiderWindowDidLeave(_ window: SpiderWindow)
}

public final class SpiderWindow: EntityWindow {
    public private(set) var position: CGPoint
    public var surfaceTop: CGFloat = 0
    public var surfaceBottom: CGFloat = 0
    public weak var spiderDelegate: SpiderWindowDelegate?

    private var hp = 2
    private var crawlTimer: Timer?
    private var dir: CGFloat = 1
    private var phase: TimeInterval = 0
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 14.0
    private var rig: QuadRig?
    private var isGone = false

    public init(startPos: CGPoint, surfaceTop: CGFloat, surfaceBottom: CGFloat, delegate: SpiderWindowDelegate) {
        self.position = startPos
        self.surfaceTop = surfaceTop
        self.surfaceBottom = surfaceBottom
        self.spiderDelegate = delegate
        let size = NSSize(width: 56, height: 44)
        super.init(contentRect: NSRect(x: startPos.x - 28, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(
            bodyColor: .rgb(0.18, 0.14, 0.16),
            headColor: .rgb(0.18, 0.14, 0.16),
            legColor: .rgb(0.15, 0.12, 0.14)
        )
        for ex in [-0.15, -0.09, -0.03, 0.03, 0.09, 0.15] as [CGFloat] {
            let eye = vbox(0.06, 0.06, 0.02, .glow(0.95, 0.15, 0.25))
            eye.position = SCNVector3(ex, 0.08, 0.25)
            rig.head.addChildNode(eye)
        }
        for spot in [SCNVector3(-0.18, -0.25, 0.0), SCNVector3(0.18, -0.25, 0.0)] {
            let leg = limbJoint(mesh: vbox(0.16, 0.45, 0.16, .rgb(0.15, 0.12, 0.14)), at: spot, drop: -0.225)
            rig.body.addChildNode(leg)
        }
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.spiderDelegate?.spiderWindowDidClick(self)
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        crawlTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.lifeTimer += 1.0 / 60.0
            if self.lifeTimer >= self.maxLife {
                self.disappear(defeated: false)
                return
            }
            self.position.y += self.dir * 70.0 / 60.0
            if self.position.y >= self.surfaceTop {
                self.position.y = self.surfaceTop
                self.dir = -1
            } else if self.position.y <= self.surfaceBottom {
                self.position.y = self.surfaceBottom
                self.dir = 1
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - 28, y: self.position.y))
            self.rig?.walk(1.0 / 60.0)
        }
        RunLoop.main.add(crawlTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        spiderDelegate?.spiderWindowDidClick(self)
    }

    public func takeHit() {
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
        crawlTimer?.invalidate()
        crawlTimer = nil
        spiderDelegate?.spiderWindowDidLeave(self)
        close()
    }

    public override func close() {
        crawlTimer?.invalidate()
        crawlTimer = nil
        super.close()
    }
}

private final class SpiderDrawView: NSView {
    var legWiggle: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setStrokeColor(red: 0.15, green: 0.12, blue: 0.14, alpha: 1.0)
        ctx.setLineWidth(2.5)
        for i in 0..<4 {
            let y = 8 + CGFloat(i) * 8
            let spread = 6 + legWiggle * 2
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 14, y: y))
            ctx.addLine(to: CGPoint(x: 14 - spread, y: y + 6))
            ctx.strokePath()
            ctx.beginPath()
            ctx.move(to: CGPoint(x: w - 14, y: y))
            ctx.addLine(to: CGPoint(x: w - 14 + spread, y: y + 6))
            ctx.strokePath()
        }
        ctx.setFillColor(red: 0.18, green: 0.14, blue: 0.16, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 8, width: w - 32, height: 24))
        ctx.setFillColor(red: 0.95, green: 0.15, blue: 0.25, alpha: 1.0)
        for x in [20, 26, 32] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: x, y: 24, width: 4, height: 4))
            ctx.fillEllipse(in: CGRect(x: w - x - 4, y: 24, width: 4, height: 4))
        }
    }
}
