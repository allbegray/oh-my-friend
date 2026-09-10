import AppKit
import CoreGraphics

public final class CropEntityWindow: EntityWindow {
    private let plantPos: CGPoint
    private let onHarvest: () -> Void
    private var stage: Int = 0
    private var growTimer: Timer?
    private var elapsed: TimeInterval = 0
    private let stageDuration: TimeInterval = 25.0
    private let maxStage: Int = 3
    private var drawView: CropDrawView?

    public var isMature: Bool { stage >= maxStage }

    public init(plantPos: CGPoint, onHarvest: @escaping () -> Void) {
        self.plantPos = plantPos
        self.onHarvest = onHarvest
        let size = NSSize(width: 56, height: 72)
        let frame = NSRect(
            x: plantPos.x - size.width / 2.0,
            y: plantPos.y,
            width: size.width,
            height: size.height
        )
        super.init(contentRect: frame, ignoresMouse: false)
        let view = CropDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func plant() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        growTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            let next = min(self.maxStage, Int(self.elapsed / self.stageDuration))
            if next > self.stage {
                self.stage = next
                self.drawView?.stage = next
                self.drawView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.pop)
            }
        }
        RunLoop.main.add(growTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        if isMature {
            onHarvest()
            close()
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
        growTimer?.invalidate()
        growTimer = nil
        super.close()
    }
}

private final class CropDrawView: NSView {
    var stage: Int = 0
    var showHint = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: w - 8, height: 10))
        let green = NSColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
        let golden = NSColor(red: 0.95, green: 0.82, blue: 0.30, alpha: 1.0)
        let color = stage >= 3 ? golden : green
        ctx.setFillColor(color.cgColor)
        let height: CGFloat = [8, 20, 34, 48][min(stage, 3)] as CGFloat
        ctx.fill(CGRect(x: w / 2.0 - 3, y: 10, width: 6, height: height))
        if stage >= 2 {
            ctx.fill(CGRect(x: w / 2.0 - 8, y: 10 + height - 12, width: 16, height: 6))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 덜 자랐어 🌱",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 58))
        }
    }
}
