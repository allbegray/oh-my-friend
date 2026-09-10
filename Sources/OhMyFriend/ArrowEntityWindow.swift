import AppKit
import CoreGraphics

/// 스켈레톤이 발사하여 플레이어를 향해 포물선으로 날아가는 3D 마인크래프트 화살 엔티티
public final class ArrowEntityWindow: EntityWindow {
    private let startPos: CGPoint
    private let targetPos: CGPoint
    private let onHit: (Bool) -> Void // parameter: isDeflected by shield
    private let checkGuarding: () -> Bool

    private var currentPos: CGPoint
    private var progress: CGFloat = 0
    private var timer: Timer?

    public init(
        startPos: CGPoint,
        targetPos: CGPoint,
        checkGuarding: @escaping () -> Bool,
        onHit: @escaping (Bool) -> Void
    ) {
        self.startPos = startPos
        self.targetPos = targetPos
        self.checkGuarding = checkGuarding
        self.onHit = onHit
        self.currentPos = startPos

        let size: CGFloat = 40.0
        let frame = NSRect(x: startPos.x - size / 2.0, y: startPos.y - size / 2.0, width: size, height: size)
        super.init(contentRect: frame, ignoresMouse: true)

        let arrowView = ArrowDrawView(frame: NSRect(origin: .zero, size: frame.size))
        arrowView.facingRight = targetPos.x >= startPos.x
        contentView = arrowView
    }

    public func launch() {
        orderFrontRegardless()
        let distance = hypot(targetPos.x - startPos.x, targetPos.y - startPos.y)
        let flightTime = max(0.4, Double(distance / 550.0)) // ~550 pt/s flight speed
        let startTime = ProcessInfo.processInfo.systemUptime

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let p = min(1.0, CGFloat(elapsed / flightTime))

            // Ballistic flight arc: interpolate X, parabolic arc Y
            let curX = self.startPos.x + (self.targetPos.x - self.startPos.x) * p
            let linearY = self.startPos.y + (self.targetPos.y - self.startPos.y) * p
            let arcHeight: CGFloat = 30.0 * sin(p * CGFloat.pi)
            let curY = linearY + arcHeight

            self.setFrameOrigin(NSPoint(x: curX - 20, y: curY - 20))

            if p >= 1.0 {
                t.invalidate()
                self.timer = nil
                let isGuarded = self.checkGuarding()
                self.onHit(isGuarded)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.close()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

private final class ArrowDrawView: NSView {
    var facingRight: Bool = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let cx = bounds.midX
        let cy = bounds.midY

        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }

        // 1. Wooden shaft (갈색 화살대)
        ctx.setFillColor(red: 0.52, green: 0.35, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 12, y: cy - 2, width: 22, height: 4))

        // 2. White feather fletching (깃털)
        ctx.setFillColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 16, y: cy - 5, width: 5, height: 10))

        // 3. Flint arrowhead (부싯돌 화살촉)
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx + 10, y: cy + 5))
        ctx.addLine(to: CGPoint(x: cx + 18, y: cy))
        ctx.addLine(to: CGPoint(x: cx + 10, y: cy - 5))
        ctx.closePath()
        ctx.fillPath()

        ctx.restoreGState()
    }
}
