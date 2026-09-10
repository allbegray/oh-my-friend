import AppKit
import CoreGraphics

public protocol SheepWindowDelegate: AnyObject {
    func sheepWindowDidClick(_ window: SheepWindow)
}

public final class SheepWindow: NSPanel {
    public private(set) var position: CGPoint
    public private(set) var hasWool: Bool = true
    public weak var sheepDelegate: SheepWindowDelegate?

    private var grazeTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var regrowTimer: TimeInterval = 0
    private let regrowDuration: TimeInterval = 60.0
    private var drawView: SheepDrawView?

    public init(startPos: CGPoint, delegate: SheepWindowDelegate) {
        self.position = startPos
        self.sheepDelegate = delegate
        let size = NSSize(width: 72, height: 52)
        super.init(
            contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height),
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
        let view = SheepDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        grazeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 30.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 36, y: self.position.y))
            if !self.hasWool {
                self.regrowTimer += 1.0 / 60.0
                if self.regrowTimer >= self.regrowDuration {
                    self.hasWool = true
                    self.regrowTimer = 0
                    self.drawView?.hasWool = true
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * 4.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(grazeTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        sheepDelegate?.sheepWindowDidClick(self)
    }

    public func shear() {
        hasWool = false
        regrowTimer = 0
        drawView?.hasWool = false
        drawView?.needsDisplay = true
    }

    public override func close() {
        grazeTimer?.invalidate()
        grazeTimer = nil
        super.close()
    }
}

private final class SheepDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0
    var hasWool = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        if hasWool {
            ctx.setFillColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 10, y: 14 + bob, width: 44, height: 30))
            ctx.fillEllipse(in: CGRect(x: 18, y: 30 + bob, width: 28, height: 16))
        } else {
            ctx.setFillColor(red: 0.75, green: 0.70, blue: 0.66, alpha: 1.0)
            ctx.fill(CGRect(x: 16, y: 16 + bob, width: 32, height: 16))
        }
        ctx.setFillColor(red: 0.80, green: 0.72, blue: 0.66, alpha: 1.0)
        ctx.fill(CGRect(x: 50, y: 20 + bob, width: 14, height: 14))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 56, y: 26 + bob, width: 3, height: 4))
        ctx.setFillColor(red: 0.80, green: 0.72, blue: 0.66, alpha: 1.0)
        for x in [20, 30, 40, 48] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 5, height: 14))
        }
        ctx.restoreGState()
    }
}
