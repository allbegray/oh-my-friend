import AppKit
import CoreGraphics

public final class CampfireWindow: NSPanel {
    private var flickerTimer: Timer?
    private var phase: TimeInterval = 0
    private var drawView: CampfireDrawView?

    public init(floorPos: CGPoint) {
        let size = NSSize(width: 76, height: 64)
        super.init(
            contentRect: NSRect(
                x: floorPos.x - size.width / 2.0,
                y: floorPos.y,
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
        let view = CampfireDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.ignite)
        flickerTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 1.0 / 12.0
            self.drawView?.flick = sin(self.phase * 9.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(flickerTimer!, forMode: .common)
    }

    public override func close() {
        flickerTimer?.invalidate()
        flickerTimer = nil
        super.close()
    }
}

private final class CampfireDrawView: NSView {
    var flick: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
        for x in [12, 30, 46] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: x, y: 2, width: 12, height: 9))
        }
        ctx.setFillColor(red: 0.40, green: 0.26, blue: 0.12, alpha: 1.0)
        ctx.saveGState()
        ctx.translateBy(x: w / 2.0, y: 14)
        ctx.rotate(by: 0.5)
        ctx.fill(CGRect(x: -22, y: -3, width: 44, height: 6))
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: w / 2.0, y: 14)
        ctx.rotate(by: -0.5)
        ctx.fill(CGRect(x: -22, y: -3, width: 44, height: 6))
        ctx.restoreGState()
        let flameH = 26 + flick * 5
        ctx.setFillColor(red: 0.95, green: 0.40, blue: 0.10, alpha: 1.0)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w / 2.0 - 12, y: 16))
        ctx.addLine(to: CGPoint(x: w / 2.0, y: 16 + flameH))
        ctx.addLine(to: CGPoint(x: w / 2.0 + 12, y: 16))
        ctx.closePath()
        ctx.fillPath()
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: w / 2.0 - 6, y: 16))
        ctx.addLine(to: CGPoint(x: w / 2.0, y: 16 + flameH * 0.6))
        ctx.addLine(to: CGPoint(x: w / 2.0 + 6, y: 16))
        ctx.closePath()
        ctx.fillPath()
    }
}
