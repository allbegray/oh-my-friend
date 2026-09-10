import AppKit
import CoreGraphics

public final class AxolotlWindow: NSPanel {
    private var followTimer: Timer?
    private var phase: TimeInterval = 0
    private var drawView: AxolotlDrawView?

    public init() {
        let size = NSSize(width: 36, height: 28)
        super.init(
            contentRect: NSRect(x: 300, y: 300, width: size.width, height: size.height),
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
        let view = AxolotlDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func perch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 1.0 / 30.0
            self.drawView?.wiggle = sin(self.phase * 6.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(followTimer!, forMode: .common)
    }

    public func moveToShoulder(playerPos: CGPoint, facingRight: Bool) {
        let offsetX: CGFloat = facingRight ? -26 : 26
        setFrameOrigin(NSPoint(x: playerPos.x + offsetX - 18, y: playerPos.y + 52))
        drawView?.facingRight = facingRight
    }

    public override func close() {
        followTimer?.invalidate()
        followTimer = nil
        super.close()
    }
}

private final class AxolotlDrawView: NSView {
    var wiggle: CGFloat = 0
    var facingRight = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.95, green: 0.55, blue: 0.65, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 6, width: w - 12, height: h - 10))
        ctx.fill(CGRect(x: w - 12, y: 8 + wiggle * 2, width: 8, height: 8))
        ctx.setFillColor(red: 0.90, green: 0.35, blue: 0.50, alpha: 1.0)
        for y in [h - 12, h - 16, h - 8] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: 2, y: y, width: 6, height: 5))
        }
        ctx.setFillColor(red: 0.15, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w - 14, y: h - 16, width: 4, height: 5))
        ctx.restoreGState()
    }
}
