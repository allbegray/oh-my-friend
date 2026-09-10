import AppKit
import CoreGraphics

public final class TridentEntityWindow: NSPanel {
    private let startPos: CGPoint
    private let targetPos: CGPoint
    private let onReturned: () -> Void

    private var progress: CGFloat = 0
    private var returning = false
    private var timer: Timer?
    private var spin: CGFloat = 0
    private var drawView: TridentDrawView?

    public init(startPos: CGPoint, targetPos: CGPoint, onReturned: @escaping () -> Void) {
        self.startPos = startPos
        self.targetPos = targetPos
        self.onReturned = onReturned

        let size: CGFloat = 56.0
        let frame = NSRect(x: startPos.x - size / 2.0, y: startPos.y - size / 2.0, width: size, height: size)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = TridentDrawView(frame: NSRect(origin: .zero, size: frame.size))
        view.facingRight = targetPos.x >= startPos.x
        self.drawView = view
        contentView = view
    }

    public func launch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.whoosh)
        let distance = hypot(targetPos.x - startPos.x, targetPos.y - startPos.y)
        let legTime = max(0.35, Double(distance / 650.0))
        let startTime = ProcessInfo.processInfo.systemUptime

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let total = legTime * 2.0
            let p = min(1.0, CGFloat(elapsed / total))
            self.spin += 0.35
            self.drawView?.spin = self.spin
            self.drawView?.needsDisplay = true

            let from = self.returning ? self.targetPos : self.startPos
            let to = self.returning ? self.startPos : self.targetPos
            let legP = min(1.0, p * 2.0 - (self.returning ? 1.0 : 0.0))
            let curX = from.x + (to.x - from.x) * legP
            let linearY = from.y + (to.y - from.y) * legP
            let arc: CGFloat = self.returning ? 0 : 26.0 * sin(legP * CGFloat.pi)
            self.setFrameOrigin(NSPoint(x: curX - 28, y: linearY + arc - 28))

            if !self.returning && p >= 0.5 {
                self.returning = true
                self.drawView?.facingRight = self.startPos.x >= self.targetPos.x
                SoundAndEffectsManager.shared.play(.whoosh)
            }
            if p >= 1.0 {
                t.invalidate()
                self.timer = nil
                self.onReturned()
                self.close()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

private final class TridentDrawView: NSView {
    var facingRight: Bool = true
    var spin: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.midX
        let cy = bounds.midY
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: spin)
        if !facingRight {
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: -2, y: -14, width: 4, height: 24))
        ctx.setFillColor(red: 0.2, green: 0.85, blue: 0.85, alpha: 1.0)
        ctx.fill(CGRect(x: -9, y: 10, width: 18, height: 3))
        for x in [-8, -1, 6] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 13, width: 3, height: 10))
        }
        ctx.restoreGState()
    }
}
