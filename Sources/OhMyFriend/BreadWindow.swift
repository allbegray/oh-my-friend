import AppKit
import CoreGraphics

public final class BreadWindow: EntityWindow {
    private let isPumpkinPie: Bool
    private let onEaten: (Bool) -> Void
    private var isBaked = false
    private var bakeTimer: Timer?
    private var elapsed: TimeInterval = 0
    private let bakeDuration: TimeInterval = 5.0
    private var drawView: BreadDrawView?

    public init(floorPos: CGPoint, isPumpkinPie: Bool, onEaten: @escaping (Bool) -> Void) {
        self.isPumpkinPie = isPumpkinPie
        self.onEaten = onEaten
        let size = NSSize(width: 64, height: 48)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = BreadDrawView(frame: NSRect(origin: .zero, size: size))
        view.isPumpkinPie = isPumpkinPie
        self.drawView = view
        contentView = view
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func bake() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        bakeTimer?.invalidate()
        elapsed = 0
        isBaked = false
        drawView?.progress = 0
        drawView?.needsDisplay = true
        bakeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            let progress = min(1.0, self.elapsed / self.bakeDuration)
            self.drawView?.progress = progress
            self.drawView?.needsDisplay = true
            SoundAndEffectsManager.shared.play(.pop)
            if self.elapsed >= self.bakeDuration {
                t.invalidate()
                self.bakeTimer = nil
                self.isBaked = true
                self.drawView?.isBaked = true
                self.drawView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.pop)
            }
        }
        if let bakeTimer = bakeTimer {
            RunLoop.main.add(bakeTimer, forMode: .common)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        if isBaked {
            onEaten(isPumpkinPie)
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
        bakeTimer?.invalidate()
        bakeTimer = nil
        super.close()
    }
}

private final class BreadDrawView: NSView {
    var progress: CGFloat = 0
    var isBaked = false
    var isPumpkinPie = false
    var showHint = false

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let t = min(1.0, max(0.0, progress))
        // 반죽 노란색 -> 완성 색 (황금 갈색 / 호박 주황)
        let dough = (r: CGFloat(0.96), g: CGFloat(0.86), b: CGFloat(0.58))
        let golden = (r: CGFloat(0.78), g: CGFloat(0.52), b: CGFloat(0.22))
        let pumpkin = (r: CGFloat(0.95), g: CGFloat(0.55), b: CGFloat(0.15))
        let target = isPumpkinPie ? pumpkin : golden
        let r = lerp(dough.r, target.r, t)
        let g = lerp(dough.g, target.g, t)
        let b = lerp(dough.b, target.b, t)

        // 접시 그림자
        ctx.setFillColor(red: 0.80, green: 0.80, blue: 0.82, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 4, y: 1, width: 56, height: 10))

        if isPumpkinPie {
            // 호박파이: 둥근 파이 + 격자 무늬 픽셀아트
            ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 48, height: 26))
            // 가장자리 크러스트
            ctx.setFillColor(red: lerp(0.88, 0.65, t), green: lerp(0.72, 0.42, t), blue: lerp(0.45, 0.18, t), alpha: 1.0)
            ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 48, height: 26))
            // 격자 무늬 (밝은 반죽 띠)
            ctx.setFillColor(red: 0.98, green: 0.88, blue: 0.62, alpha: 1.0)
            let lattice: [CGRect] = [
                CGRect(x: 14, y: 18, width: 36, height: 4),
                CGRect(x: 14, y: 26, width: 36, height: 4),
                CGRect(x: 22, y: 10, width: 4, height: 22),
                CGRect(x: 32, y: 10, width: 4, height: 22),
                CGRect(x: 42, y: 10, width: 4, height: 22)
            ]
            for rect in lattice {
                ctx.fill(rect)
            }
        } else {
            // 황금빵: 둥근 식빵 몸통 + 윗면 하이라이트
            ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
            ctx.fill(CGRect(x: 10, y: 8, width: 44, height: 20))
            ctx.fillEllipse(in: CGRect(x: 10, y: 22, width: 44, height: 12))
            ctx.setFillColor(red: min(1.0, r + 0.12), green: min(1.0, g + 0.10), blue: min(1.0, b + 0.08), alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 16, y: 26, width: 32, height: 6))
            // 구움 표시 (완성 시 갈색 스코어선)
            if isBaked {
                ctx.setFillColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 1.0)
                ctx.fill(CGRect(x: 18, y: 16, width: 28, height: 2))
                ctx.fill(CGRect(x: 22, y: 12, width: 20, height: 2))
            }
        }

        // 굽는 중 지글 표시
        if !isBaked && progress > 0 {
            ctx.setFillColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
            let flicker = (Int(progress * 5.0) % 2 == 0)
            if flicker {
                ctx.fillEllipse(in: CGRect(x: 28, y: 36, width: 4, height: 6))
                ctx.fillEllipse(in: CGRect(x: 36, y: 38, width: 3, height: 5))
            } else {
                ctx.fillEllipse(in: CGRect(x: 24, y: 38, width: 3, height: 5))
                ctx.fillEllipse(in: CGRect(x: 32, y: 36, width: 4, height: 6))
            }
        }

        if showHint {
            let text = NSAttributedString(
                string: "지글지글 굽는 중...",
                attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 0))
        }
    }
}
