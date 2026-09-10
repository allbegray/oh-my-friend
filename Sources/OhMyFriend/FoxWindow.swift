import AppKit
import CoreGraphics

public protocol FoxWindowDelegate: AnyObject {
    func foxWindowDidClick(_ window: FoxWindow)
    func foxWindowDidEscape(_ window: FoxWindow)
}

public final class FoxWindow: EntityWindow {
    public private(set) var position: CGPoint
    public var carriedEmoji: String?
    public weak var foxDelegate: FoxWindowDelegate?

    private var dartTimer: Timer?
    private var lifeTimer: TimeInterval = 0
    private let maxLife: TimeInterval = 14.0
    private var dir: CGFloat = 1
    private var drawView: FoxDrawView?
    private var isGone = false

    public init(startPos: CGPoint, delegate: FoxWindowDelegate) {
        self.position = startPos
        self.foxDelegate = delegate
        let size = NSSize(width: 64, height: 44)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = FoxDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        dartTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.lifeTimer += 1.0 / 60.0
            if Int(self.lifeTimer * 3.0) % 5 == 0 && Int(self.lifeTimer * 60.0) % 60 < 2 {
                self.dir = Bool.random() ? 1 : -1
            }
            let dash = 170.0 + min(120.0, self.lifeTimer * 20.0)
            self.position.x += self.dir * dash / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 32, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.carriedEmoji = self.carriedEmoji
            self.drawView?.needsDisplay = true
            if self.lifeTimer >= self.maxLife {
                self.disappear(escaped: true)
            }
        }
        RunLoop.main.add(dartTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        foxDelegate?.foxWindowDidClick(self)
    }

    public func disappear(escaped: Bool) {
        guard !isGone else { return }
        isGone = true
        dartTimer?.invalidate()
        dartTimer = nil
        if escaped {
            foxDelegate?.foxWindowDidEscape(self)
        }
        close()
    }

    public override func close() {
        dartTimer?.invalidate()
        dartTimer = nil
        super.close()
    }
}

private final class FoxDrawView: NSView {
    var facingRight = true
    var carriedEmoji: String?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.90, green: 0.45, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 6, width: 36, height: 20))
        ctx.fill(CGRect(x: 40, y: 10, width: 14, height: 12))
        ctx.setFillColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1.0)
        ctx.fill(CGRect(x: 50, y: 12, width: 6, height: 8))
        ctx.setFillColor(red: 0.90, green: 0.45, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 26, width: 8, height: 10))
        ctx.fill(CGRect(x: 24, y: 26, width: 8, height: 10))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 44, y: 18, width: 4, height: 4))
        ctx.setFillColor(red: 0.90, green: 0.45, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 8, width: 12, height: 8))
        ctx.setFillColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 8, width: 5, height: 8))
        ctx.restoreGState()
        if let item = carriedEmoji {
            let text = NSAttributedString(
                string: item,
                attributes: [.font: NSFont.systemFont(ofSize: 16)]
            )
            text.draw(at: NSPoint(x: w / 2.0 - 9, y: h - 20))
        }
    }
}
