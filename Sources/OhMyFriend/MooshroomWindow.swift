import AppKit
import CoreGraphics

public protocol MooshroomWindowDelegate: AnyObject {
    func mooshroomWindowDidClick(_ window: MooshroomWindow)
}

public final class MooshroomWindow: NSPanel {
    public private(set) var position: CGPoint
    public weak var mooshroomDelegate: MooshroomWindowDelegate?

    private var wanderTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var mooCooldown: TimeInterval = 6.0
    private var drawView: MooshroomDrawView?

    public init(startPos: CGPoint, delegate: MooshroomWindowDelegate) {
        self.position = startPos
        self.mooshroomDelegate = delegate
        let size = NSSize(width: 84, height: 60)
        super.init(
            contentRect: NSRect(x: startPos.x - 42, y: startPos.y, width: size.width, height: size.height),
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
        let view = MooshroomDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.mooCooldown -= 1.0 / 60.0
            if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 300 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            if self.mooCooldown <= 0 {
                self.mooCooldown = Double.random(in: 8.0...16.0)
                self.drawView?.mooFlash = 0.8
            }
            self.position.x += self.dir * 20.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 42, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * 3.0)
            if let dv = self.drawView, dv.mooFlash > 0 {
                dv.mooFlash -= 1.0 / 60.0
            }
            // 스튜 획득 직후 하트 파티클 표시 시간 감소
            if let dv = self.drawView, dv.heartFlash > 0 {
                dv.heartFlash -= 1.0 / 60.0
                if dv.heartFlash <= 0 {
                    dv.needsDisplay = true
                }
            }
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(wanderTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        mooshroomDelegate?.mooshroomWindowDidClick(self)
    }

    /// 빈 양동이(HeldItem.emptyBucket)를 든 상태에서 클릭 시 AppController 콜백에서 호출.
    /// 스튜 획득 연출: 꿀꺽 사운드 + 하트 파티클.
    public func collectStew() {
        SoundAndEffectsManager.shared.play(.gulp)
        drawView?.heartFlash = 1.2
        drawView?.needsDisplay = true
    }

    public override func close() {
        wanderTimer?.invalidate()
        wanderTimer = nil
        super.close()
    }
}

private final class MooshroomDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0
    var mooFlash: TimeInterval = 0
    var heartFlash: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통: 빨간 무쉬룸 소
        ctx.setFillColor(red: 0.78, green: 0.18, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 14 + bob, width: 46, height: 24))
        // 흰 반점 2개
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 24 + bob, width: 10, height: 8))
        ctx.fill(CGRect(x: 44, y: 18 + bob, width: 8, height: 8))
        // 머리
        ctx.setFillColor(red: 0.78, green: 0.18, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 58, y: 20 + bob, width: 16, height: 16))
        // 머리 흰 반점
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: 62, y: 28 + bob, width: 6, height: 5))
        // 눈
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fill(CGRect(x: 68, y: 27 + bob, width: 3, height: 4))
        // 코
        ctx.setFillColor(red: 0.93, green: 0.80, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 66, y: 20 + bob, width: 8, height: 5))
        // 등에 난 빨간 버섯 2송이 (갓 + 기둥)
        // 버섯 1
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: 29, y: 38 + bob, width: 4, height: 6))
        ctx.setFillColor(red: 0.85, green: 0.20, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 25, y: 43 + bob, width: 12, height: 6))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 27, y: 45 + bob, width: 3, height: 3))
        ctx.fill(CGRect(x: 32, y: 44 + bob, width: 3, height: 3))
        // 버섯 2
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: 47, y: 38 + bob, width: 4, height: 6))
        ctx.setFillColor(red: 0.85, green: 0.20, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 43, y: 43 + bob, width: 12, height: 6))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 45, y: 45 + bob, width: 3, height: 3))
        ctx.fill(CGRect(x: 50, y: 44 + bob, width: 3, height: 3))
        // 다리 4개
        ctx.setFillColor(red: 0.62, green: 0.14, blue: 0.12, alpha: 1.0)
        for x in [18, 28, 44, 54] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 6, height: 13))
        }
        // 음메 플래시: 머리 위 음표 느낌의 흰 점
        if mooFlash > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: CGFloat(min(1.0, mooFlash)))
            ctx.fillEllipse(in: CGRect(x: 64, y: 44 + bob, width: 8, height: 8))
        }
        // 스튜 획득 하트 파티클
        if heartFlash > 0 {
            let a = CGFloat(min(1.0, heartFlash))
            ctx.setFillColor(red: 1.0, green: 0.30, blue: 0.45, alpha: a)
            let hy = 46 + bob + (1.2 - CGFloat(heartFlash)) * 8.0
            ctx.fillEllipse(in: CGRect(x: 38, y: hy, width: 7, height: 7))
            ctx.fillEllipse(in: CGRect(x: 43, y: hy, width: 7, height: 7))
            ctx.fill(CGRect(x: 39, y: hy - 4, width: 10, height: 6))
        }
        ctx.restoreGState()
    }
}
