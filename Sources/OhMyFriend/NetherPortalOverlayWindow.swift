import AppKit
import CoreGraphics

public final class NetherPortalOverlayWindow: EntityWindow {
    public let floorPos: CGPoint
    public private(set) var hasEntered = false
    private var swirlTimer: Timer?
    private var swirlPhase: CGFloat = 0
    private var drawView: PortalDrawView?

    public init(floorPos: CGPoint) {
        self.floorPos = floorPos
        let size = NSSize(width: 110, height: 150)
        let frame = NSRect(
            x: floorPos.x - size.width / 2.0,
            y: floorPos.y,
            width: size.width,
            height: size.height
        )
        super.init(contentRect: frame, ignoresMouse: true)
        let view = PortalDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func open() {
        orderFrontRegardless()
        swirlTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.swirlPhase += 0.12
            self.drawView?.swirlPhase = self.swirlPhase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(swirlTimer!, forMode: .common)
    }

    public func markEntered() {
        hasEntered = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.hasEntered = false
        }
    }

    public override func close() {
        swirlTimer?.invalidate()
        swirlTimer = nil
        super.close()
    }
}

private final class PortalDrawView: NSView {
    var swirlPhase: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.08, green: 0.06, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: 12))
        ctx.fill(CGRect(x: 0, y: h - 12, width: w, height: 12))
        ctx.fill(CGRect(x: 0, y: 0, width: 12, height: h))
        ctx.fill(CGRect(x: w - 12, y: 0, width: 12, height: h))
        let inner = CGRect(x: 12, y: 12, width: w - 24, height: h - 24)
        ctx.setFillColor(red: 0.35, green: 0.05, blue: 0.55, alpha: 0.85)
        ctx.fill(inner)
        ctx.saveGState()
        ctx.clip(to: inner)
        for i in 0..<5 {
            let t = swirlPhase + CGFloat(i) * 0.9
            let bandW: CGFloat = 10
            let x = inner.minX + (inner.width / 2.0) + sin(t) * (inner.width / 2.0) - bandW / 2.0
            ctx.setFillColor(red: 0.65, green: 0.25, blue: 0.95, alpha: 0.55)
            ctx.fill(CGRect(x: x, y: inner.minY, width: bandW, height: inner.height))
        }
        ctx.restoreGState()
    }
}
