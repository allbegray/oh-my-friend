import AppKit
import CoreGraphics

public protocol ZombieWindowDelegate: AnyObject {
    func zombieWindowDidClick(_ window: ZombieWindow)
    func zombieWindowDidDefeat(_ window: ZombieWindow)
}

public final class ZombieWindow: NSPanel {
    public private(set) var position: CGPoint
    public weak var zombieDelegate: ZombieWindowDelegate?

    private var hp = 2
    private var chaseTimer: Timer?
    private var phase: TimeInterval = 0
    private var drawView: ZombieDrawView?
    private var isGone = false
    public var target: CGPoint = .zero

    public init(startPos: CGPoint, delegate: ZombieWindowDelegate) {
        self.position = startPos
        self.target = startPos
        self.zombieDelegate = delegate
        let size = NSSize(width: 44, height: 66)
        super.init(
            contentRect: NSRect(x: startPos.x - 22, y: startPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = ZombieDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        chaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            let dx = self.target.x - self.position.x
            let dir: CGFloat = dx >= 0 ? 1 : -1
            if abs(dx) > 34 {
                self.position.x += dir * 95.0 / 60.0
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - 22, y: self.position.y))
            self.drawView?.facingRight = dir > 0
            self.drawView?.step = sin(self.phase * 10.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(chaseTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        zombieDelegate?.zombieWindowDidClick(self)
    }

    public func takeHit() {
        hp -= 1
        if hp <= 0 {
            guard !isGone else { return }
            isGone = true
            chaseTimer?.invalidate()
            chaseTimer = nil
            zombieDelegate?.zombieWindowDidDefeat(self)
            close()
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    public func dismiss() {
        guard !isGone else { return }
        isGone = true
        chaseTimer?.invalidate()
        chaseTimer = nil
        close()
    }

    public override func close() {
        chaseTimer?.invalidate()
        chaseTimer = nil
        super.close()
    }
}

private final class ZombieDrawView: NSView {
    var facingRight = true
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.25, green: 0.55, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 22, width: 20, height: 24))
        ctx.fill(CGRect(x: 12, y: 44, width: 22, height: 18))
        ctx.setFillColor(red: 0.20, green: 0.45, blue: 0.30, alpha: 1.0)
        let armSwing = step * 4
        ctx.fill(CGRect(x: 30, y: 26 + armSwing, width: 8, height: 18))
        ctx.setFillColor(red: 0.25, green: 0.55, blue: 0.35, alpha: 1.0)
        let legSwing = step * 3
        ctx.fill(CGRect(x: 16, y: 4, width: 8, height: 18 + legSwing))
        ctx.fill(CGRect(x: 26, y: 4, width: 8, height: 18 - legSwing))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 18, y: 52, width: 4, height: 5))
        ctx.fillEllipse(in: CGRect(x: 26, y: 52, width: 4, height: 5))
        ctx.restoreGState()
    }
}
