import AppKit
import CoreGraphics
import SceneKit

public final class BeeEntityWindow: EntityWindow {
    public var followOffset: CGPoint = .zero
    private var wobble: CGFloat = 0
    private var rig: FlyerRig?

    public init(startPos: CGPoint) {
        let size = NSSize(width: 30, height: 26)
        super.init(contentRect: NSRect(x: startPos.x - 15, y: startPos.y, width: size.width, height: size.height), ignoresMouse: true)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(
            bodyColor: .rgb(0.95, 0.75, 0.15),
            wingColor: .rgb(1.0, 1.0, 1.0)
        )
        for z in [-0.08, 0.06] as [CGFloat] {
            let stripe = vbox(0.34, 0.10, 0.05, .rgb(0.15, 0.12, 0.10))
            stripe.position = SCNVector3(0, 0.05, z)
            rig.body.addChildNode(stripe)
        }
        let stinger = vbox(0.08, 0.08, 0.10, .rgb(0.15, 0.12, 0.10))
        stinger.position = SCNVector3(0, -0.05, -0.20)
        rig.body.addChildNode(stinger)
        rig.addTo(view.scene!, scale: 0.9)
        view.setSubject(rig)
        self.rig = rig
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func follow(target: CGPoint, excited: Bool) {
        wobble += excited ? 0.35 : 0.18
        rig?.flap(excited ? 1.0 / 30.0 : 1.0 / 60.0)
        let wob = sin(wobble) * (excited ? 16.0 : 9.0)
        setFrameOrigin(NSPoint(
            x: target.x + followOffset.x,
            y: target.y + followOffset.y + wob
        ))
    }
}

public final class BeehiveEntityWindow: EntityWindow {
    private let floorPos: CGPoint
    private let onCollect: () -> Void
    private var honeyTimer: Timer?
    private var honeyReady = false
    private var drawView: BeehiveDrawView?

    public init(floorPos: CGPoint, onCollect: @escaping () -> Void) {
        self.floorPos = floorPos
        self.onCollect = onCollect
        let size = NSSize(width: 76, height: 84)
        super.init(contentRect: NSRect(
            x: floorPos.x - size.width / 2.0,
            y: floorPos.y,
            width: size.width,
            height: size.height
        ), ignoresMouse: false)
        let view = BeehiveDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        honeyTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.honeyReady = true
            self.drawView?.honeyReady = true
            self.drawView?.needsDisplay = true
            SoundAndEffectsManager.shared.play(.chime)
        }
        RunLoop.main.add(honeyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        if honeyReady {
            honeyReady = false
            drawView?.honeyReady = false
            drawView?.needsDisplay = true
            onCollect()
            honeyTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.honeyReady = true
                self.drawView?.honeyReady = true
                self.drawView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.chime)
            }
            RunLoop.main.add(honeyTimer!, forMode: .common)
        } else {
            drawView?.showHint = true
            drawView?.needsDisplay = true
            SoundAndEffectsManager.shared.play(.pop)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.drawView?.showHint = false
                self?.drawView?.needsDisplay = true
            }
        }
    }

    public override func close() {
        honeyTimer?.invalidate()
        honeyTimer = nil
        super.close()
    }
}

private final class BeehiveDrawView: NSView {
    var honeyReady = false
    var showHint = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.75, green: 0.55, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 8, width: w - 36, height: 44))
        ctx.setFillColor(red: 0.60, green: 0.42, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 26, width: w - 36, height: 5))
        ctx.fill(CGRect(x: 18, y: 40, width: w - 36, height: 5))
        ctx.setFillColor(red: 0.30, green: 0.18, blue: 0.06, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 7, y: 12, width: 14, height: 10))
        if honeyReady {
            ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.15, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: w / 2.0 - 5, y: 52, width: 10, height: 14))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 꿀이 없어 🐝",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 68))
        }
    }
}
