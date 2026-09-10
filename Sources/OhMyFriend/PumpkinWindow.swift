import AppKit
import CoreGraphics
import Foundation

public final class PumpkinWard {
    public static let shared = PumpkinWard()
    private init() {}
    public var hasPumpkin: Bool = false
    public var isWorn: Bool = false
}

public final class PumpkinWindow: NSPanel {
    private let plantPos: CGPoint
    private let onHarvest: () -> Void
    private var stage: Int = 0
    private var growTimer: Timer?
    private var elapsed: TimeInterval = 0
    private let stageDuration: TimeInterval = 15.0
    private let maxStage: Int = 3
    private var drawView: PumpkinDrawView?

    public var isMature: Bool { stage >= maxStage }

    public init(plantPos: CGPoint, onHarvest: @escaping () -> Void) {
        self.plantPos = plantPos
        self.onHarvest = onHarvest
        let size = NSSize(width: 64, height: 76)
        let frame = NSRect(
            x: plantPos.x - size.width / 2.0,
            y: plantPos.y,
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
        let view = PumpkinDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
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

private final class PumpkinDrawView: NSView {
    var stage: Int = 0
    var showHint = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: w - 8, height: 10))
        let stem = NSColor(red: 0.25, green: 0.60, blue: 0.20, alpha: 1.0)
        let pumpkin = NSColor(red: 1.0, green: 0.55, blue: 0.10, alpha: 1.0)
        let pumpkinDark = NSColor(red: 0.82, green: 0.40, blue: 0.05, alpha: 1.0)
        let pumpkinLight = NSColor(red: 1.0, green: 0.70, blue: 0.25, alpha: 1.0)
        ctx.setFillColor(stem.cgColor)
        let stemHeight: CGFloat = [8, 22, 26, 30][min(stage, 3)] as CGFloat
        ctx.fill(CGRect(x: w / 2.0 - 2.5, y: 10, width: 5, height: stemHeight))
        if stage >= 1 {
            ctx.fill(CGRect(x: w / 2.0 - 10, y: 10 + stemHeight - 10, width: 8, height: 4))
            ctx.fill(CGRect(x: w / 2.0 + 2, y: 10 + stemHeight - 14, width: 8, height: 4))
        }
        if stage == 2 {
            ctx.setFillColor(pumpkin.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 10, y: 10, width: 20, height: 14))
            ctx.setFillColor(pumpkinDark.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 10, y: 10, width: 3, height: 14))
            ctx.fill(CGRect(x: w / 2.0 + 7, y: 10, width: 3, height: 14))
            ctx.fill(CGRect(x: w / 2.0 - 1.5, y: 10, width: 3, height: 14))
        }
        if stage >= 3 {
            ctx.setFillColor(pumpkin.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 20, y: 10, width: 40, height: 30))
            ctx.setFillColor(pumpkinLight.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 14, y: 12, width: 7, height: 26))
            ctx.fill(CGRect(x: w / 2.0 + 1, y: 12, width: 7, height: 26))
            ctx.setFillColor(pumpkinDark.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 20, y: 10, width: 4, height: 30))
            ctx.fill(CGRect(x: w / 2.0 + 16, y: 10, width: 4, height: 30))
            ctx.fill(CGRect(x: w / 2.0 - 6, y: 10, width: 3, height: 30))
            ctx.fill(CGRect(x: w / 2.0 + 3, y: 10, width: 3, height: 30))
            ctx.setFillColor(stem.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 3, y: 40, width: 6, height: 8))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 덜 익었어 🎃",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 62))
        }
    }
}
