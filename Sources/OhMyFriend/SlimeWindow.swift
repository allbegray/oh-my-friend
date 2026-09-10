import AppKit
import CoreGraphics
import SceneKit

public enum SlimeSize: CaseIterable {
    case big
    case medium
    case small

    public func smaller() -> SlimeSize? {
        switch self {
        case .big: return .medium
        case .medium: return .small
        case .small: return nil
        }
    }

    public var hitPoints: Int {
        switch self {
        case .big: return 3
        case .medium: return 2
        case .small: return 1
        }
    }

    public var panelSize: CGFloat {
        switch self {
        case .big: return 96
        case .medium: return 64
        case .small: return 40
        }
    }
}

public protocol SlimeWindowDelegate: AnyObject {
    func slimeWindowDidSplit(_ window: SlimeWindow, size: SlimeSize, at pos: CGPoint)
    func slimeWindowDidDespawn(_ window: SlimeWindow)
    func attackSlime(_ slime: SlimeWindow)
}

public final class SlimeWindow: EntityWindow {
    public let slimeSize: SlimeSize
    public private(set) var position: CGPoint
    public weak var slimeDelegate: SlimeWindowDelegate?

    private var hp: Int
    private var hopTimer: Timer?
    private var hopPhase: CGFloat = 0
    private var direction: CGFloat = 1
    private var rig: CubeRig?
    private var isDead = false

    public init(size: SlimeSize, startPos: CGPoint, delegate: SlimeWindowDelegate) {
        self.slimeSize = size
        self.position = startPos
        self.slimeDelegate = delegate
        self.hp = size.hitPoints
        let s = size.panelSize
        let frame = NSRect(x: startPos.x - s / 2.0, y: startPos.y, width: s, height: s)
        super.init(contentRect: frame, ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: frame.size))
        let cubeSize: CGFloat
        switch size {
        case .big: cubeSize = 1.2
        case .medium: cubeSize = 0.85
        case .small: cubeSize = 0.6
        }
        let rig = CubeRig(color: .rgb(0.25, 0.85, 0.35), size: cubeSize, alpha: 0.82)
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.slimeDelegate?.attackSlime(self)
        }
        contentView = view
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        hopTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.hopPhase += 1.0 / 60.0
            if Int(self.hopPhase * 2.0) % 4 == 0 && Int(self.hopPhase * 60.0) % 60 == 0 {
                self.direction = Bool.random() ? 1 : -1
            }
            let hopCycle = self.hopPhase.truncatingRemainder(dividingBy: 0.9)
            let hopHeight: CGFloat = hopCycle < 0.45 ? sin(hopCycle / 0.45 * CGFloat.pi) * 26.0 : 0
            if hopCycle < 0.45 {
                self.position.x += self.direction * 55.0 / 60.0
            }
            let s = self.slimeSize.panelSize
            self.setFrameOrigin(NSPoint(x: self.position.x - s / 2.0, y: self.position.y + hopHeight))
            self.rig?.squash(hopCycle < 0.45 ? 0.05 : 0.45)
        }
        RunLoop.main.add(hopTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        slimeDelegate?.attackSlime(self)
    }

    public func takeHit() {
        guard !isDead else { return }
        hp -= 1
        if hp <= 0 {
            isDead = true
            hopTimer?.invalidate()
            hopTimer = nil
            if slimeSize.smaller() != nil {
                slimeDelegate?.slimeWindowDidSplit(self, size: slimeSize, at: position)
            } else {
                slimeDelegate?.slimeWindowDidDespawn(self)
            }
            close()
        }
    }

    public override func close() {
        hopTimer?.invalidate()
        hopTimer = nil
        super.close()
    }
}

private final class SlimeDrawView: NSView {
    var squash: CGFloat = 1.0
    var flash: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let bodyH = h * 0.72 / squash
        let bodyW = w * 0.86 * squash
        let bx = (w - bodyW) / 2.0
        let by = (h - bodyH) / 2.0
        let alpha: CGFloat = 0.82
        if flash > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alpha)
            flash = 0
        } else {
            ctx.setFillColor(red: 0.25, green: 0.85, blue: 0.35, alpha: alpha)
        }
        ctx.fill(CGRect(x: bx, y: by, width: bodyW, height: bodyH))
        ctx.setFillColor(red: 0.45, green: 0.95, blue: 0.55, alpha: alpha)
        ctx.fill(CGRect(x: bx + 4, y: by + bodyH - 8, width: bodyW - 8, height: 5))
        ctx.setFillColor(red: 0.08, green: 0.12, blue: 0.10, alpha: 1.0)
        let eyeSize = max(4, w * 0.1)
        ctx.fill(CGRect(x: bx + bodyW * 0.22, y: by + bodyH * 0.45, width: eyeSize, height: eyeSize * 1.4))
        ctx.fill(CGRect(x: bx + bodyW * 0.62, y: by + bodyH * 0.45, width: eyeSize, height: eyeSize * 1.4))
        ctx.fill(CGRect(x: bx + bodyW * 0.35, y: by + bodyH * 0.2, width: bodyW * 0.3, height: 3))
    }
}
