import AppKit
import CoreGraphics

public final class MelonWindow: EntityWindow {
    private let plantPos: CGPoint
    private let onSlice: (Bool) -> Void
    private var stage: Int = 0
    private var growTimer: Timer?
    private var elapsed: TimeInterval = 0
    private let stageDuration: TimeInterval = 20.0
    private let maxStage: Int = 3
    private var drawView: MelonDrawView?

    public var isMature: Bool { stage >= maxStage }

    public init(plantPos: CGPoint, onSlice: @escaping (Bool) -> Void) {
        self.plantPos = plantPos
        self.onSlice = onSlice
        let size = NSSize(width: 72, height: 80)
        let frame = NSRect(
            x: plantPos.x - size.width / 2.0,
            y: plantPos.y,
            width: size.width,
            height: size.height
        )
        super.init(contentRect: frame, ignoresMouse: false)
        let view = MelonDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public required init?(coder: NSCoder) {
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
            let isGlistering = Double.random(in: 0..<1) < 0.25
            SoundAndEffectsManager.shared.play(.splash)
            onSlice(isGlistering)
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

private final class MelonDrawView: NSView {
    var stage: Int = 0
    var showHint = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 흙
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 10))
        // 덩굴 줄기 (수평 + 새싹)
        let vine = NSColor(red: 0.22, green: 0.55, blue: 0.22, alpha: 1.0)
        ctx.setFillColor(vine.cgColor)
        let vineLength: CGFloat = [10, 26, 44, 56][min(stage, 3)] as CGFloat
        ctx.fill(CGRect(x: w / 2.0 - vineLength / 2.0, y: 10, width: vineLength, height: 4))
        let sproutHeight: CGFloat = [8, 14, 10, 8][min(stage, 3)] as CGFloat
        ctx.fill(CGRect(x: w / 2.0 - 2, y: 10, width: 4, height: sproutHeight))
        // 잎
        if stage >= 1 {
            let leaf = NSColor(red: 0.30, green: 0.70, blue: 0.30, alpha: 1.0)
            ctx.setFillColor(leaf.cgColor)
            ctx.fill(CGRect(x: w / 2.0 - 16, y: 12, width: 10, height: 6))
            ctx.fill(CGRect(x: w / 2.0 + 6, y: 12, width: 10, height: 6))
        }
        // 수박 열매
        if stage >= 2 {
            let isBig = stage >= 3
            let mw: CGFloat = isBig ? 34 : 20
            let mh: CGFloat = isBig ? 28 : 16
            let mx = w / 2.0 - mw / 2.0
            let my: CGFloat = 18
            // 초록 몸통
            ctx.setFillColor(red: 0.18, green: 0.62, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: mx, y: my, width: mw, height: mh))
            // 줄무늬 (진한 초록 세로줄)
            ctx.setFillColor(red: 0.10, green: 0.42, blue: 0.16, alpha: 1.0)
            let stripeW: CGFloat = 4
            var sx = mx + 3
            while sx < mx + mw - 2 {
                ctx.fill(CGRect(x: sx, y: my, width: stripeW, height: mh))
                sx += stripeW + 6
            }
            // 꼭지
            ctx.setFillColor(red: 0.35, green: 0.25, blue: 0.12, alpha: 1.0)
            ctx.fill(CGRect(x: w / 2.0 - 2, y: my + mh, width: 4, height: 4))
            if isBig {
                // 반짝이는 수박 힌트: 노란 반점
                ctx.setFillColor(red: 1.0, green: 0.90, blue: 0.35, alpha: 1.0)
                ctx.fill(CGRect(x: mx + 6, y: my + 8, width: 4, height: 4))
                ctx.fill(CGRect(x: mx + mw - 10, y: my + 16, width: 4, height: 4))
            }
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 덜 자랐어 🍈",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 64))
        }
    }
}
