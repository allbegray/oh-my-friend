import AppKit
import CoreGraphics

public final class PotatoWindow: EntityWindow {
    private let plantPos: CGPoint
    private let onHarvest: (Bool) -> Void
    private var stage: Int = 0
    private var growTimer: Timer?
    private var elapsed: TimeInterval = 0
    private let stageDuration: TimeInterval = 25.0
    private let maxStage: Int = 3
    private var drawView: PotatoDrawView?

    public var isMature: Bool { stage >= maxStage }

    public init(plantPos: CGPoint, onHarvest: @escaping (Bool) -> Void) {
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
        let view = PotatoDrawView(frame: NSRect(origin: .zero, size: size))
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
            let isRotten = Double.random(in: 0..<1) < 0.2
            drawView?.isRotten = isRotten
            drawView?.needsDisplay = true
            onHarvest(isRotten)
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

private final class PotatoDrawView: NSView {
    var stage: Int = 0
    var showHint = false
    var isRotten = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 갈색 흙
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: w - 8, height: 10))
        // 초록 잎 줄기 (단계별 성장)
        let leaf = NSColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
        ctx.setFillColor(leaf.cgColor)
        let height: CGFloat = [8, 20, 34, 48][min(stage, 3)] as CGFloat
        ctx.fill(CGRect(x: w / 2.0 - 3, y: 10, width: 6, height: height))
        if stage >= 1 {
            ctx.fill(CGRect(x: w / 2.0 - 10, y: 10 + height - 10, width: 7, height: 5))
            ctx.fill(CGRect(x: w / 2.0 + 3, y: 10 + height - 14, width: 7, height: 5))
        }
        if stage >= 2 {
            ctx.fill(CGRect(x: w / 2.0 - 9, y: 10 + height - 20, width: 6, height: 5))
            ctx.fill(CGRect(x: w / 2.0 + 3, y: 10 + height - 24, width: 6, height: 5))
        }
        // 갈색 감자 (2단계부터 흙 위 노출, 성숙 시 대형 / 썩은감자는 초록빛)
        if stage >= 2 {
            let potatoColor: NSColor
            if isRotten {
                potatoColor = NSColor(red: 0.35, green: 0.6, blue: 0.25, alpha: 1.0)
            } else if stage >= 3 {
                potatoColor = NSColor(red: 0.72, green: 0.53, blue: 0.30, alpha: 1.0)
            } else {
                potatoColor = NSColor(red: 0.6, green: 0.44, blue: 0.25, alpha: 1.0)
            }
            ctx.setFillColor(potatoColor.cgColor)
            let pw: CGFloat = stage >= 3 ? 22 : 14
            let ph: CGFloat = stage >= 3 ? 12 : 8
            ctx.fill(CGRect(x: w / 2.0 - pw / 2.0, y: 8, width: pw, height: ph))
            // 감자 눈(斑点)
            ctx.setFillColor(red: 0.35, green: 0.24, blue: 0.12, alpha: 1.0)
            ctx.fill(CGRect(x: w / 2.0 - 5, y: 11, width: 3, height: 3))
            ctx.fill(CGRect(x: w / 2.0 + 3, y: 13, width: 3, height: 3))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 덜 자랐어 🥔",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 58))
        }
    }
}
