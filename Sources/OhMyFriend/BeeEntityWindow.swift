import AppKit
import CoreGraphics

public final class BeeEntityWindow: NSPanel {
    public var followOffset: CGPoint = .zero
    private var wobble: CGFloat = 0

    public init(startPos: CGPoint) {
        let size = NSSize(width: 30, height: 26)
        super.init(
            contentRect: NSRect(x: startPos.x - 15, y: startPos.y, width: size.width, height: size.height),
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
        contentView = BeeDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func follow(target: CGPoint, excited: Bool) {
        wobble += excited ? 0.35 : 0.18
        let wob = sin(wobble) * (excited ? 16.0 : 9.0)
        setFrameOrigin(NSPoint(
            x: target.x + followOffset.x,
            y: target.y + followOffset.y + wob
        ))
    }
}

private final class BeeDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.75)
        ctx.fillEllipse(in: CGRect(x: 2, y: h - 12, width: 9, height: 8))
        ctx.fillEllipse(in: CGRect(x: w - 11, y: h - 12, width: 9, height: 8))
        ctx.setFillColor(red: 0.95, green: 0.75, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 4, width: w - 12, height: h - 12))
        ctx.setFillColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 11, y: 5, width: 3, height: h - 13))
        ctx.fill(CGRect(x: 17, y: 5, width: 3, height: h - 13))
    }
}

public final class BeehiveEntityWindow: NSPanel {
    private let floorPos: CGPoint
    private let onCollect: () -> Void
    private var honeyTimer: Timer?
    private var honeyReady = false
    private var drawView: BeehiveDrawView?

    public init(floorPos: CGPoint, onCollect: @escaping () -> Void) {
        self.floorPos = floorPos
        self.onCollect = onCollect
        let size = NSSize(width: 76, height: 84)
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
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = BeehiveDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        honeyTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.honeyReady = true
            self.drawView?.honeyReady = true
            self.drawView?.needsDisplay = true
            SoundAndEffectsManager.shared.play(.chime)
        }
        RunLoop.main.add(honeyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        if honeyReady {
            honeyReady = false
            drawView?.honeyReady = false
            drawView?.needsDisplay = true
            onCollect()
            honeyTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.honeyReady = true
                self.drawView?.honeyReady = true
                self.drawView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.chime)
            }
            RunLoop.main.add(honeyTimer!, forMode: .common)
        } else {
            drawView?.showHint = true
            drawView?.needsDisplay = true
            SoundAndEffectsManager.shared.play(.pop)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.drawView?.showHint = false
                self?.drawView?.needsDisplay = true
            }
        }
    }

    public override func close() {
        honeyTimer?.invalidate()
        honeyTimer = nil
        super.close()
    }
}

private final class BeehiveDrawView: NSView {
    var honeyReady = false
    var showHint = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.75, green: 0.55, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 8, width: w - 36, height: 44))
        ctx.setFillColor(red: 0.60, green: 0.42, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 26, width: w - 36, height: 5))
        ctx.fill(CGRect(x: 18, y: 40, width: w - 36, height: 5))
        ctx.setFillColor(red: 0.30, green: 0.18, blue: 0.06, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 7, y: 12, width: 14, height: 10))
        if honeyReady {
            ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.15, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: w / 2.0 - 5, y: 52, width: 10, height: 14))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 꿀이 없어 🐝",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 68))
        }
    }
}
