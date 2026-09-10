import AppKit
import CoreGraphics

public final class TargetWindow: NSPanel {
    public var centerPos: CGPoint = .zero

    public init(centerPos: CGPoint) {
        self.centerPos = centerPos
        let size = NSSize(width: 90, height: 90)
        super.init(
            contentRect: NSRect(
                x: centerPos.x - size.width / 2.0,
                y: centerPos.y - size.height / 2.0,
                width: size.width,
                height: size.height
            ),
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
        contentView = TargetDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
}

private final class TargetDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let c = CGPoint(x: w / 2.0, y: bounds.height / 2.0)
        let rings: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (40, 0.90, 0.90, 0.90), (31, 0.15, 0.15, 0.15),
            (22, 0.20, 0.55, 0.95), (13, 0.95, 0.20, 0.20), (5, 0.95, 0.85, 0.20),
        ]
        for (r, red, green, blue) in rings {
            ctx.setFillColor(red: red, green: green, blue: blue, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: 6, height: 18))
        ctx.fill(CGRect(x: w - 10, y: 0, width: 6, height: 18))
    }
}

public final class BatWindow: NSPanel {
    public var anchor: CGPoint = .zero
    private var flyTimer: Timer?
    private var phase: TimeInterval = 0
    private var squeakTimer: TimeInterval = 6.0
    private let anchorProvider: () -> CGPoint
    private var drawView: BatDrawView?

    public init(anchorProvider: @escaping () -> CGPoint) {
        self.anchorProvider = anchorProvider
        self.anchor = anchorProvider()
        let size = NSSize(width: 40, height: 30)
        super.init(
            contentRect: NSRect(x: anchor.x, y: anchor.y + 120, width: size.width, height: size.height),
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
        let view = BatDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.anchor = self.anchorProvider()
            let cx = self.anchor.x + cos(self.phase * 1.4) * 90.0
            let cy = self.anchor.y + 130 + sin(self.phase * 2.3) * 30.0
            self.setFrameOrigin(NSPoint(x: cx - 20, y: cy))
            self.drawView?.flap = sin(self.phase * 18.0)
            self.drawView?.needsDisplay = true
            self.squeakTimer -= 1.0 / 60.0
            if self.squeakTimer <= 0 {
                self.squeakTimer = Double.random(in: 8.0...15.0)
                SoundAndEffectsManager.shared.play(.heart)
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class BatDrawView: NSView {
    var flap: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let wingY = h / 2 + flap * 6
        ctx.setFillColor(red: 0.25, green: 0.20, blue: 0.28, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 2, y: wingY - 4, width: 14, height: 12))
        ctx.fillEllipse(in: CGRect(x: w - 16, y: wingY - 4, width: 14, height: 12))
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 8, y: h / 2.0 - 8, width: 16, height: 16))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w / 2.0 - 6, y: h / 2.0 + 8))
        ctx.addLine(to: CGPoint(x: w / 2.0 - 3, y: h / 2.0 + 14))
        ctx.addLine(to: CGPoint(x: w / 2.0, y: h / 2.0 + 8))
        ctx.closePath()
        ctx.fillPath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w / 2.0, y: h / 2.0 + 8))
        ctx.addLine(to: CGPoint(x: w / 2.0 + 3, y: h / 2.0 + 14))
        ctx.addLine(to: CGPoint(x: w / 2.0 + 6, y: h / 2.0 + 8))
        ctx.closePath()
        ctx.fillPath()
        ctx.setFillColor(red: 0.95, green: 0.20, blue: 0.30, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 5, y: h / 2.0, width: 3, height: 4))
        ctx.fillEllipse(in: CGRect(x: w / 2.0 + 2, y: h / 2.0, width: 3, height: 4))
    }
}
