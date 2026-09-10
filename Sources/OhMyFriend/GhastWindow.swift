import AppKit
import CoreGraphics

public protocol GhastWindowDelegate: AnyObject {
    func ghastDidDefeat(_ window: GhastWindow)
    func ghastDidLeave(_ window: GhastWindow)
}

public final class GhastWindow: NSPanel {
    public var anchor: CGPoint = .zero
    public weak var ghastDelegate: GhastWindowDelegate?

    private var hp = 3
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var shootTimer: TimeInterval = 5.0
    private let onShoot: (CGPoint) -> Void
    private var drawView: GhastDrawView?
    private var isGone = false

    public init(startPos: CGPoint, delegate: GhastWindowDelegate, onShoot: @escaping (CGPoint) -> Void) {
        self.anchor = startPos
        self.ghastDelegate = delegate
        self.onShoot = onShoot
        let size = NSSize(width: 110, height: 90)
        super.init(
            contentRect: NSRect(x: startPos.x - 55, y: startPos.y, width: size.width, height: size.height),
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
        let view = GhastDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
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
            self.drawView?.mouthOpen = self.shootTimer < 0.8
            self.drawView?.needsDisplay = true
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

private final class GhastDrawView: NSView {
    var mouthOpen = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 0.95)
        ctx.fill(CGRect(x: 22, y: 22, width: w - 44, height: h - 32))
        for x in [8, w - 20] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 40, width: 12, height: 22))
        }
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 34, y: 52, width: 8, height: 10))
        ctx.fillEllipse(in: CGRect(x: w - 42, y: 52, width: 8, height: 10))
        if mouthOpen {
            ctx.setFillColor(red: 0.75, green: 0.10, blue: 0.10, alpha: 1.0)
            ctx.fill(CGRect(x: w / 2.0 - 9, y: 28, width: 18, height: 16))
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: w / 2.0 - 5, y: 32, width: 10, height: 8))
        } else {
            ctx.fill(CGRect(x: w / 2.0 - 6, y: 34, width: 12, height: 4))
        }
        for i in 0..<4 {
            let x = 30 + CGFloat(i) * 13
            ctx.setFillColor(red: 0.94, green: 0.94, blue: 0.94, alpha: 0.9)
            ctx.fill(CGRect(x: x, y: 8 + CGFloat(i % 2) * 4, width: 8, height: 14))
        }
    }
}

public final class FireballWindow: NSPanel {
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
        super.init(
            contentRect: NSRect(x: from.x - 17, y: from.y - 17, width: size, height: size),
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
