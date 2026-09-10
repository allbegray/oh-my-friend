import AppKit
import CoreGraphics

public final class WindowSquashOverlayWindow: NSPanel {
    private let targetFrame: CGRect
    private let duration: TimeInterval
    private let completion: () -> Void
    private var startTime: TimeInterval = 0
    private var animTimer: Timer?
    private let overlayView = SquashDrawView()

    public init(targetFrame: CGRect, duration: TimeInterval = 2.0, completion: @escaping () -> Void) {
        self.targetFrame = targetFrame
        self.duration = duration
        self.completion = completion

        // 패널 여백 추가
        let padded = targetFrame.insetBy(dx: -40, dy: -40)
        super.init(
            contentRect: padded,
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

        overlayView.frame = NSRect(origin: .zero, size: padded.size)
        overlayView.targetInView = CGRect(x: 40, y: 40, width: targetFrame.width, height: targetFrame.height)
        contentView = overlayView
    }

    public func start() {
        self.startTime = ProcessInfo.processInfo.systemUptime
        orderFrontRegardless()

        SoundAndEffectsManager.shared.play(.ignite)

        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - self.startTime
            let progress = min(1.0, CGFloat(elapsed / self.duration))

            self.overlayView.progress = progress
            self.overlayView.needsDisplay = true

            if progress >= 1.0 {
                t.invalidate()
                self.animTimer = nil
                self.completion()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.close()
                }
            }
        }
        RunLoop.main.add(animTimer!, forMode: .common)
    }

    public func cancel() {
        animTimer?.invalidate()
        animTimer = nil
        close()
    }
}

private final class SquashDrawView: NSView {
    var progress: CGFloat = 0
    var targetInView: CGRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        guard targetInView.width > 0 && targetInView.height > 0 else { return }

        // 1. 하강하는 압축 프레스 판 (Piston Plate)
        // progress: 0.0(최상단) -> 1.0(최하단 근처)
        let totalTravel = targetInView.height - 30.0
        let currentPlateTopY = targetInView.maxY - (totalTravel * progress)
        let plateHeight: CGFloat = 24.0
        let plateRect = CGRect(
            x: targetInView.minX - 10,
            y: currentPlateTopY - plateHeight,
            width: targetInView.width + 20,
            height: plateHeight
        )

        // 2. 압축 기둥 (Piston Rods)
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 0.85)
        let rodWidth: CGFloat = 16.0
        let rod1 = CGRect(x: targetInView.minX + targetInView.width * 0.25, y: plateRect.maxY, width: rodWidth, height: targetInView.maxY - plateRect.maxY + 10)
        let rod2 = CGRect(x: targetInView.minX + targetInView.width * 0.75 - rodWidth, y: plateRect.maxY, width: rodWidth, height: targetInView.maxY - plateRect.maxY + 10)
        ctx.fill(rod1)
        ctx.fill(rod2)

        // 3. 묵직한 강철 압축판 (Iron Press Plate)
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 0.95)
        ctx.fill(plateRect)

        // 노란색/검은색 경고 스트라이프 (Hazard Stripes)
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 0.90)
        let stripeW: CGFloat = 20.0
        var sx = plateRect.minX
        while sx < plateRect.maxX {
            let sRect = CGRect(x: sx, y: plateRect.minY + 4, width: stripeW, height: 6)
            ctx.fill(sRect)
            sx += stripeW * 2.0
        }

        // 4. 측면 증기/먼지 파티클 (Steam & Dust)
        let seed = Int(progress * 100)
        for i in 0..<8 {
            let pSeed = (seed + i * 37) % 100
            let pAlpha = max(0, 1.0 - progress) * 0.7
            ctx.setFillColor(red: 0.85, green: 0.85, blue: 0.85, alpha: pAlpha)

            let pSize: CGFloat = CGFloat(6 + (pSeed % 8))
            let pLeft = CGRect(
                x: plateRect.minX - CGFloat(pSeed % 25),
                y: plateRect.minY + CGFloat((pSeed * 3) % 20),
                width: pSize,
                height: pSize
            )
            let pRight = CGRect(
                x: plateRect.maxX + CGFloat(pSeed % 25) - pSize,
                y: plateRect.minY + CGFloat((pSeed * 5) % 20),
                width: pSize,
                height: pSize
            )
            ctx.fill(pLeft)
            ctx.fill(pRight)
        }
    }
}
