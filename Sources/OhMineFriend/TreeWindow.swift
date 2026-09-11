import AppKit
import CoreGraphics

public protocol TreeWindowDelegate: AnyObject {
    func treeWindowDidEatApple()
    func treeWindowDidChop(logs: Int, apples: Int)
}

public extension TreeWindowDelegate {
    func treeWindowDidEatApple() {}
    func treeWindowDidChop(logs: Int, apples: Int) {}
}

public final class TreeWindow: EntityWindow {
    private let plantPos: CGPoint
    private weak var treeDelegate: TreeWindowDelegate?
    private var stage: Int = 0
    private var growTimer: Timer?
    private var appleTimer: Timer?
    private var elapsed: TimeInterval = 0
    private var matureElapsed: TimeInterval = 0
    private let stageDuration: TimeInterval = 4.5
    private let maxStage: Int = 3
    private let appleInterval: TimeInterval = 3.5
    private let maxApples = 3
    private var apples: [AppleWindow] = []
    private var drawView: TreeDrawView?

    public var isMature: Bool { stage >= maxStage }

    public init(plantPos: CGPoint, delegate: TreeWindowDelegate) {
        self.plantPos = plantPos
        self.treeDelegate = delegate
        let size = NSSize(width: 72, height: 120)
        let frame = NSRect(
            x: plantPos.x - size.width / 2.0,
            y: plantPos.y,
            width: size.width,
            height: size.height
        )
        super.init(contentRect: frame, ignoresMouse: false)
        self.autoDismissDuration = 0
        let view = TreeDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func start() {
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
            if self.isMature {
                self.matureElapsed += 1.0
                if self.matureElapsed >= 15.0 {
                    self.treeDelegate?.treeWindowDidChop(logs: 3, apples: 1)
                    self.close()
                }
            }
        }
        RunLoop.main.add(growTimer!, forMode: .common)
        appleTimer = Timer.scheduledTimer(withTimeInterval: appleInterval, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            guard self.isMature else { return }
            self.dropApple()
        }
        RunLoop.main.add(appleTimer!, forMode: .common)
    }

    public func chop() {
        growTimer?.invalidate()
        growTimer = nil
        appleTimer?.invalidate()
        appleTimer = nil
        drawView?.showChop = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.splash)
        let fallen = apples.count
        for apple in apples {
            apple.close()
        }
        apples.removeAll()
        treeDelegate?.treeWindowDidChop(logs: 2, apples: fallen)
        close()
    }

    public override func mouseDown(with event: NSEvent) {
        guard !isMature else { return }
        drawView?.showHint = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.pop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.drawView?.showHint = false
            self?.drawView?.needsDisplay = true
        }
    }

    public override func close() {
        growTimer?.invalidate()
        growTimer = nil
        appleTimer?.invalidate()
        appleTimer = nil
        for apple in apples {
            apple.close()
        }
        apples.removeAll()
        super.close()
    }

    private func dropApple() {
        apples = apples.filter { $0.isVisible }
        guard apples.count < maxApples else { return }
        let applePos = CGPoint(
            x: plantPos.x + CGFloat.random(in: -20...20),
            y: plantPos.y - 4
        )
        let apple = AppleWindow(floorPos: applePos) { [weak self] tapped in
            self?.handleAppleTap(tapped)
        }
        apples.append(apple)
        apple.place()
    }

    private func handleAppleTap(_ apple: AppleWindow) {
        apples.removeAll { $0 === apple }
        apple.close()
        SoundAndEffectsManager.shared.play(.gulp)
        treeDelegate?.treeWindowDidEatApple()
    }
}

public final class AppleWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AppleWindow) -> Void
    private var drawView: AppleDrawView?

    public init(floorPos: CGPoint, onTap: @escaping (AppleWindow) -> Void) {
        self.position = floorPos
        self.onTap = onTap
        let size = NSSize(width: 20, height: 24)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = AppleDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        scheduleAutoDismiss(after: 8.0) { [weak self] in
            guard let self = self else { return }
            self.onTap(self)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        super.close()
    }
}

private final class TreeDrawView: NSView {
    var stage: Int = 0
    var showHint = false
    var showChop = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 흙
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 8))
        let cx = w / 2.0
        // 줄기 (단계별 키 증가)
        let trunkHeights: [CGFloat] = [10, 28, 48, 68]
        let trunkH = trunkHeights[min(stage, 3)]
        ctx.setFillColor(red: 0.42, green: 0.27, blue: 0.13, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 4, y: 8, width: 8, height: trunkH))
        if stage >= 1 {
            // 가지
            ctx.fill(CGRect(x: cx - 12, y: 8 + trunkH - 14, width: 8, height: 4))
            ctx.fill(CGRect(x: cx + 4, y: 8 + trunkH - 20, width: 8, height: 4))
        }
        // 잎 (단계별 크기 증가, 0단계는 새싹)
        if stage == 0 {
            ctx.setFillColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: cx - 2, y: 18, width: 4, height: 10))
            ctx.fillEllipse(in: CGRect(x: cx - 7, y: 26, width: 6, height: 5))
            ctx.fillEllipse(in: CGRect(x: cx + 1, y: 26, width: 6, height: 5))
        } else {
            let leafSizes: [CGFloat] = [0, 28, 44, 58]
            let leaf = leafSizes[min(stage, 3)]
            let leafY = 8 + trunkH - 10
            let green = stage >= 3
                ? NSColor(red: 0.15, green: 0.55, blue: 0.20, alpha: 1.0)
                : NSColor(red: 0.25, green: 0.68, blue: 0.28, alpha: 1.0)
            ctx.setFillColor(green.cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - leaf / 2.0, y: leafY, width: leaf, height: leaf * 0.75))
            ctx.setFillColor(red: 0.20, green: 0.60, blue: 0.24, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: cx - leaf / 2.0 + 6, y: leafY + 8, width: leaf - 12, height: leaf * 0.55))
            if stage >= 3 {
                // 성목 사과 점 3개
                ctx.setFillColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1.0)
                ctx.fillEllipse(in: CGRect(x: cx - 16, y: leafY + 10, width: 7, height: 7))
                ctx.fillEllipse(in: CGRect(x: cx + 9, y: leafY + 14, width: 7, height: 7))
                ctx.fillEllipse(in: CGRect(x: cx - 3, y: leafY + 26, width: 7, height: 7))
            }
        }
        if showChop {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55)
            ctx.fill(CGRect(x: cx - 14, y: 8, width: 28, height: trunkH + 8))
        }
        if showHint {
            let text = NSAttributedString(
                string: "아직 덜 자랐어 🌱",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            text.draw(at: NSPoint(x: 0, y: 104))
        }
    }
}

private final class AppleDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 꼭지 (갈색)
        ctx.setFillColor(red: 0.42, green: 0.27, blue: 0.13, alpha: 1.0)
        ctx.fill(CGRect(x: 9, y: 19, width: 2, height: 4))
        // 잎 (초록)
        ctx.setFillColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 11, y: 19, width: 6, height: 4))
        // 사과 몸통 (빨강)
        ctx.setFillColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: 16, height: 18))
        // 광택 하이라이트
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: 5, y: 12, width: 4, height: 6))
    }
}
