import AppKit
import CoreGraphics

public protocol ChickenWindowDelegate: AnyObject {
    func chickenWindowDidClick(_ window: ChickenWindow)
    func chickenWindowDidHatchChick(_ parent: ChickenWindow, chick: ChickenWindow)
}

public extension ChickenWindowDelegate {
    func chickenWindowDidClick(_ window: ChickenWindow) {}
    func chickenWindowDidHatchChick(_ parent: ChickenWindow, chick: ChickenWindow) {}
}

public final class ChickenWindow: NSPanel {
    public var position: CGPoint
    public let scale: CGFloat
    public weak var chickenDelegate: ChickenWindowDelegate?

    private var wanderTimer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var layTimer: TimeInterval = 0
    private let layInterval: TimeInterval = 20.0
    private let maxEggs = 3
    private var eggs: [EggWindow] = []
    private var chicks: [ChickenWindow] = []
    private var drawView: ChickenDrawView?
    private var panelW: CGFloat = 60
    private var panelH: CGFloat = 48

    public init(startPos: CGPoint, delegate: ChickenWindowDelegate, scale: CGFloat = 1.0) {
        self.position = startPos
        self.scale = scale
        self.chickenDelegate = delegate
        let w: CGFloat = 60 * scale
        let h: CGFloat = 48 * scale
        self.panelW = w
        self.panelH = h
        super.init(
            contentRect: NSRect(x: startPos.x - w / 2.0, y: startPos.y, width: w, height: h),
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
        let view = ChickenDrawView(frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 30.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2.0, y: self.position.y))
            if self.scale >= 1.0 {
                self.layTimer += 1.0 / 60.0
                if self.layTimer >= self.layInterval {
                    self.layTimer = 0
                    self.layEgg()
                }
            }
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * 6.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(wanderTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        chickenDelegate?.chickenWindowDidClick(self)
    }

    public override func close() {
        wanderTimer?.invalidate()
        wanderTimer = nil
        for egg in eggs {
            egg.close()
        }
        eggs.removeAll()
        super.close()
    }

    public func layEgg() {
        eggs = eggs.filter { $0.isVisible }
        guard eggs.count < maxEggs else { return }
        let eggPos = CGPoint(x: position.x + CGFloat.random(in: -12...12), y: position.y - 4)
        let egg = EggWindow(floorPos: eggPos) { [weak self] tapped in
            self?.handleEggClicked(tapped)
        }
        eggs.append(egg)
        egg.place()
    }

    public func handleEggClicked(_ egg: EggWindow) {
        let eggPos = egg.position
        eggs.removeAll { $0 === egg }
        egg.close()
        if Double.random(in: 0..<1) < 0.3 {
            guard let delegate = chickenDelegate else { return }
            let chick = ChickenWindow(startPos: eggPos, delegate: delegate, scale: 0.5)
            chicks.append(chick)
            chick.start()
            chickenDelegate?.chickenWindowDidHatchChick(self, chick: chick)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }
}

public final class EggWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (EggWindow) -> Void
    private var drawView: EggDrawView?

    public init(floorPos: CGPoint, onTap: @escaping (EggWindow) -> Void) {
        self.position = floorPos
        self.onTap = onTap
        let size = NSSize(width: 24, height: 28)
        super.init(
            contentRect: NSRect(
                x: floorPos.x - size.width / 2.0,
                y: floorPos.y,
                width: size.width,
                height: size.height
            ),
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
        let view = EggDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        super.close()
    }
}

private final class ChickenDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let sx = w / 60.0
        let sy = h / 48.0
        ctx.saveGState()
        ctx.scaleBy(x: sx, y: sy)
        if !facingRight {
            ctx.translateBy(x: 60, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        let lift = bob * 1.5
        // 다리 2개 (주황)
        ctx.setFillColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 2, width: 3, height: 10))
        ctx.fill(CGRect(x: 34, y: 2, width: 3, height: 10))
        // 몸통 (흰색 타원)
        ctx.setFillColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 10 + lift, width: 32, height: 22))
        // 날개 (연회색)
        ctx.setFillColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 18, y: 14 + lift + bob, width: 16, height: 12))
        // 꼬리 (흰색 깃)
        ctx.setFillColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 22 + lift, width: 8, height: 8))
        // 머리 (흰색)
        ctx.setFillColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 38, y: 26 + lift, width: 16, height: 14))
        // 볏 (빨강 3칸)
        ctx.setFillColor(red: 0.90, green: 0.12, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 41, y: 40 + lift, width: 4, height: 5))
        ctx.fill(CGRect(x: 45, y: 41 + lift, width: 4, height: 6))
        ctx.fill(CGRect(x: 49, y: 40 + lift, width: 4, height: 5))
        // 부리 (주황 삼각 대신 사각 2단)
        ctx.setFillColor(red: 1.0, green: 0.65, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 52, y: 31 + lift, width: 6, height: 4))
        // 눈 (검정)
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 47, y: 33 + lift, width: 3, height: 4))
        ctx.restoreGState()
    }
}

private final class EggDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 알 몸통 (크림색 타원)
        ctx.setFillColor(red: 0.97, green: 0.94, blue: 0.86, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 3, y: 2, width: 18, height: 24))
        // 광택 하이라이트
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
        ctx.fillEllipse(in: CGRect(x: 7, y: 16, width: 5, height: 7))
        // 얼룩 점 2개
        ctx.setFillColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 8, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 9, y: 12, width: 3, height: 3))
    }
}
