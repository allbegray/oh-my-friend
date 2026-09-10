import AppKit
import CoreGraphics
import SceneKit

public protocol FoxWindowDelegate: AnyObject {
    func foxWindowDidClick(_ window: FoxWindow)
    func foxWindowDidEscape(_ window: FoxWindow)
}

public final class FoxWindow: EntityWindow {
    public private(set) var position: CGPoint
    public var carriedEmoji: String?
    public weak var foxDelegate: FoxWindowDelegate?

    private var dartTimer: Timer?
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 14.0
    private var dir: CGFloat = 1
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var emojiLabel: NSTextField?
    private var isGone = false

    public init(startPos: CGPoint, delegate: FoxWindowDelegate) {
        self.position = startPos
        self.foxDelegate = delegate
        let size = NSSize(width: 64, height: 44)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let orange = VoxelColor.rgb(0.90, 0.45, 0.12)
        let cream = VoxelColor.rgb(0.95, 0.92, 0.88)
        let r = QuadRig(bodyColor: orange, headColor: orange, legColor: orange, tailColor: orange)
        let earL = vbox(0.12, 0.20, 0.08, orange)
        earL.position = SCNVector3(-0.14, 0.32, 0)
        r.head.addChildNode(earL)
        let earR = vbox(0.12, 0.20, 0.08, orange)
        earR.position = SCNVector3(0.14, 0.32, 0)
        r.head.addChildNode(earR)
        let eyeMat = VoxelColor.rgb(0.10, 0.10, 0.10)
        let eyeL = vbox(0.07, 0.07, 0.02, eyeMat)
        eyeL.position = SCNVector3(-0.10, 0.05, 0.25)
        r.head.addChildNode(eyeL)
        let eyeR = vbox(0.07, 0.07, 0.02, eyeMat)
        eyeR.position = SCNVector3(0.10, 0.05, 0.25)
        r.head.addChildNode(eyeR)
        let tip = vbox(0.14, 0.14, 0.14, cream)
        tip.position = SCNVector3(0, 0.36, -0.24)
        r.tail.addChildNode(tip)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 16)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.frame = NSRect(x: 0, y: size.height - 22, width: size.width, height: 20)
        label.alignment = .center
        view.addSubview(label)
        self.emojiLabel = label
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.foxDelegate?.foxWindowDidClick(self)
        }
        contentView = view
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        dartTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.lifeTimer += 1.0 / 60.0
            if Int(self.lifeTimer * 3.0) % 5 == 0 && Int(self.lifeTimer * 60.0) % 60 < 2 {
                self.dir = Bool.random() ? 1 : -1
            }
            let dash = 170.0 + min(120.0, self.lifeTimer * 20.0)
            self.position.x += self.dir * dash / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 32, y: self.position.y))
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = CGFloat(self.dir > 0 ? Double.pi / 2.0 : -Double.pi / 2.0)
            self.emojiLabel?.stringValue = self.carriedEmoji ?? ""
            if self.lifeTimer >= self.maxLife {
                self.disappear(escaped: true)
            }
        }
        RunLoop.main.add(dartTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        foxDelegate?.foxWindowDidClick(self)
    }

    public func disappear(escaped: Bool) {
        guard !isGone else { return }
        isGone = true
        dartTimer?.invalidate()
        dartTimer = nil
        if escaped {
            foxDelegate?.foxWindowDidEscape(self)
        }
        close()
    }

    public override func close() {
        dartTimer?.invalidate()
        dartTimer = nil
        super.close()
    }
}
