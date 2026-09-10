import AppKit
import CoreGraphics

public final class JukeboxEntityWindow: NSPanel {
    private let floorPos: CGPoint
    private let onFinished: () -> Void
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private let duration: TimeInterval = 8.0

    public init(floorPos: CGPoint, onFinished: @escaping () -> Void) {
        self.floorPos = floorPos
        self.onFinished = onFinished
        let size = NSSize(width: 72, height: 88)
        let frame = NSRect(
            x: floorPos.x - size.width / 2.0,
            y: floorPos.y,
            width: size.width,
            height: size.height
        )
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
        contentView = JukeboxDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.chime)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0 / 60.0
            if self.elapsed >= self.duration {
                t.invalidate()
                self.timer = nil
                self.onFinished()
                self.close()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    public override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class JukeboxDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 0, width: w - 12, height: 52))
        ctx.setFillColor(red: 0.15, green: 0.12, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 52, width: w - 12, height: 10))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        let disc = CGRect(x: w / 2.0 - 12, y: 56, width: 24, height: 12)
        ctx.fillEllipse(in: disc)
        ctx.setFillColor(red: 0.85, green: 0.15, blue: 0.55, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 3, y: 59, width: 6, height: 6))
        let note = NSAttributedString(
            string: "♪",
            attributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.systemPurple]
        )
        note.draw(at: NSPoint(x: w / 2.0 - 8, y: 66))
    }
}
