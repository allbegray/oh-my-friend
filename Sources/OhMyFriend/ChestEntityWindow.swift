import AppKit
import CoreGraphics

public final class ChestEntityWindow: NSPanel {
    private let floorPos: CGPoint
    private let onOpened: () -> Void
    private var isOpened = false
    private var drawView: ChestDrawView?

    public init(floorPos: CGPoint, onOpened: @escaping () -> Void) {
        self.floorPos = floorPos
        self.onOpened = onOpened
        let size = NSSize(width: 84, height: 64)
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
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = ChestDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        guard !isOpened else { return }
        isOpened = true
        drawView?.isOpened = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.chime)
        let loot = ["💎 다이아몬드!", "🟢 에메랄드!", "🍎 황금사과!"].randomElement() ?? "💎 다이아몬드!"
        drawView?.lootText = loot
        drawView?.needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self else { return }
            self.onOpened()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.close()
            }
        }
    }
}

private final class ChestDrawView: NSView {
    var isOpened = false
    var lootText: String?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.55, green: 0.36, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 30))
        ctx.setFillColor(red: 0.42, green: 0.26, blue: 0.10, alpha: 1.0)
        if isOpened {
            ctx.fill(CGRect(x: 8, y: 30, width: w - 16, height: 8))
        } else {
            ctx.fill(CGRect(x: 8, y: 30, width: w - 16, height: 18))
        }
        ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 5, y: 26, width: 10, height: 10))
        if isOpened, let loot = lootText {
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 0.9)
            ctx.fill(CGRect(x: w / 2.0 - 14, y: 40, width: 28, height: 12))
            let text = NSAttributedString(
                string: loot,
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 2, y: 50))
        }
    }
}
