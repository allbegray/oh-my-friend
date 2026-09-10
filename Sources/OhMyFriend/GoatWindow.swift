import AppKit
import CoreGraphics

public final class GoatWindow: EntityWindow {
    public var targetX: CGFloat = 0
    private let onRam: () -> Void
    private let onMilk: () -> Void
    private var position: CGPoint
    private var aiTimer: Timer?
    private var phase: GoatPhase = .graze
    private var phaseTimer: TimeInterval = 3.0
    private var dir: CGFloat = 1
    private var drawView: GoatDrawView?
    private var didHitThisCharge = false

    private enum GoatPhase {
        case graze
        case aim
        case charge
    }

    public init(startPos: CGPoint, onRam: @escaping () -> Void, onMilk: @escaping () -> Void) {
        self.position = startPos
        self.onRam = onRam
        self.onMilk = onMilk
        self.targetX = startPos.x
        let size = NSSize(width: 72, height: 56)
        super.init(contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = GoatDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        aiTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phaseTimer -= 1.0 / 60.0
            switch self.phase {
            case .graze:
                if self.phaseTimer <= 0 {
                    self.phase = .aim
                    self.phaseTimer = 0.8
                    self.dir = self.targetX >= self.position.x ? 1 : -1
                    self.drawView?.isAiming = true
                    self.drawView?.needsDisplay = true
                    SoundAndEffectsManager.shared.play(.alert)
                }
            case .aim:
                if self.phaseTimer <= 0 {
                    self.phase = .charge
                    self.phaseTimer = 1.2
                    self.didHitThisCharge = false
                }
            case .charge:
                self.position.x += self.dir * 380.0 / 60.0
                self.setFrameOrigin(NSPoint(x: self.position.x - 36, y: self.position.y))
                if !self.didHitThisCharge && abs(self.targetX - self.position.x) < 50 {
                    self.didHitThisCharge = true
                    self.onRam()
                }
                if self.phaseTimer <= 0 {
                    self.phase = .graze
                    self.phaseTimer = Double.random(in: 2.5...4.5)
                    self.drawView?.isAiming = false
                    self.drawView?.needsDisplay = true
                }
            }
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(aiTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onMilk()
    }

    public override func close() {
        aiTimer?.invalidate()
        aiTimer = nil
        super.close()
    }
}

private final class GoatDrawView: NSView {
    var facingRight = true
    var isAiming = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        let body: CGFloat = isAiming ? 0.75 : 0.90
        ctx.setFillColor(red: body, green: body, blue: body * 0.96, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 10, width: 36, height: 22))
        ctx.fill(CGRect(x: 44, y: 18, width: 14, height: 14))
        ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 56, y: 24, width: 8, height: 4))
        ctx.fill(CGRect(x: 56, y: 14, width: 8, height: 4))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 48, y: 24, width: 3, height: 3))
        ctx.setFillColor(red: body, green: body, blue: body * 0.96, alpha: 1.0)
        for x in [18, 28, 38, 46] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 0, width: 5, height: 12))
        }
        ctx.setFillColor(red: body, green: body, blue: body * 0.96, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 14, width: 10, height: 8))
        if isAiming {
            ctx.setFillColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 46, y: 34, width: 8, height: 8))
        }
        ctx.restoreGState()
    }
}
