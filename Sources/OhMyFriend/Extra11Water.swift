import AppKit
import CoreGraphics
import Foundation

// 11차 백로그: 물 5종(발광오징어·복어·기포기둥·스펀지·무지개) + WaterManager.
// - 기존 파일 수정 없음. WeatherManager는 읽기(isRaining) + 공개 API(isEnabled)만 사용.
// - RewardCenter 브리지(grant/say/me/movePlayer/heldItemName)만 사용, 네트워크/UserDefaults 없음.

public final class GlowSquidWindow: NSPanel {
    public var onTap: (() -> Void)?
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var baseY: CGFloat = 0
    private var drawView: GlowSquidDrawView?

    public init(startPos: CGPoint) {
        self.baseY = startPos.y
        let size = NSSize(width: 72, height: 64)
        super.init(
            contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height),
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
        let view = GlowSquidDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            let bob = sin(self.phase * 2.0) * 10.0
            let f = self.frame
            self.setFrameOrigin(NSPoint(x: f.origin.x, y: self.baseY + bob))
            self.drawView?.phase = CGFloat(self.phase)
            self.drawView?.needsDisplay = true
        }
        if let tick = tick { RunLoop.main.add(tick, forMode: .common) }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class GlowSquidDrawView: NSView {
    var phase: CGFloat = 0

    private var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 6
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bob = sin(phase * 2.0) * 2.0
        ctx.setFillColor(red: 0.10, green: 0.55, blue: 0.60, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 24 + bob, width: 32, height: 26))
        ctx.setFillColor(red: 0.25, green: 0.80, blue: 0.85, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 38 + bob, width: 24, height: 8))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 28, y: 30 + bob, width: 7, height: 9))
        ctx.fillEllipse(in: CGRect(x: 39, y: 30 + bob, width: 7, height: 9))
        ctx.setFillColor(red: 0.05, green: 0.10, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30, y: 32 + bob, width: 3, height: 5))
        ctx.fillEllipse(in: CGRect(x: 41, y: 32 + bob, width: 3, height: 5))
        ctx.setStrokeColor(red: 0.10, green: 0.45, blue: 0.50, alpha: 1.0)
        ctx.setLineWidth(3.0)
        for i in 0..<5 {
            let x = CGFloat(24 + i * 6)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: x, y: 24 + bob))
            ctx.addLine(to: CGPoint(x: x + sin(phase * 3.0 + CGFloat(i)) * 3.0, y: 10 + bob))
            ctx.strokePath()
        }
        let dots: [CGPoint] = [
            CGPoint(x: 16, y: 44), CGPoint(x: 54, y: 44),
            CGPoint(x: 14, y: 28), CGPoint(x: 56, y: 28),
            CGPoint(x: 22, y: 54), CGPoint(x: 48, y: 54),
            CGPoint(x: 30, y: 14), CGPoint(x: 42, y: 12),
        ]
        for (i, p) in dots.enumerated() {
            let blink = 0.5 + 0.5 * sin(phase * 3.0 + CGFloat(i) * 0.9)
            let alpha: CGFloat = isNight ? (0.35 + 0.65 * blink) : 0.15
            ctx.setFillColor(red: 0.45, green: 1.0, blue: 0.95, alpha: alpha)
            ctx.fillEllipse(in: CGRect(x: p.x - 2, y: p.y - 2 + bob * 0.3, width: 4, height: 4))
        }
    }
}

public final class PufferfishWindow: NSPanel {
    public var onTap: (() -> Void)?
    public private(set) var isPuffed = false
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var pos: CGPoint
    private var drawView: PufferfishDrawView?

    public init(startPos: CGPoint) {
        self.pos = startPos
        let size = NSSize(width: 64, height: 56)
        super.init(
            contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height),
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
        let view = PufferfishDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            if Int(self.phase * 30.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.pos.x += self.dir * 25.0 / 30.0
            self.pos.y += sin(self.phase * 2.5) * 8.0 / 30.0
            self.setFrameOrigin(NSPoint(x: self.pos.x - 32, y: self.pos.y))
            let me = RewardCenter.me()
            let d = hypot(me.x - self.pos.x, me.y - self.pos.y)
            let puffed = d < 60.0
            if puffed != self.isPuffed {
                self.isPuffed = puffed
                self.drawView?.isPuffed = puffed
            }
            self.drawView?.phase = CGFloat(self.phase)
            self.drawView?.needsDisplay = true
        }
        if let tick = tick { RunLoop.main.add(tick, forMode: .common) }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class PufferfishDrawView: NSView {
    var isPuffed = false
    var phase: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx: CGFloat = 32
        let cy: CGFloat = 28
        let r: CGFloat = isPuffed ? 22 : 15
        if isPuffed {
            ctx.setStrokeColor(red: 0.55, green: 0.40, blue: 0.20, alpha: 1.0)
            ctx.setLineWidth(2.5)
            for i in 0..<10 {
                let a = CGFloat(i) * .pi / 5.0 + phase * 0.4
                ctx.beginPath()
                ctx.move(to: CGPoint(x: cx + cos(a) * (r - 2), y: cy + sin(a) * (r - 2)))
                ctx.addLine(to: CGPoint(x: cx + cos(a) * (r + 7), y: cy + sin(a) * (r + 7)))
                ctx.strokePath()
            }
        }
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 8, y: cy + 1, width: 6, height: 8))
        ctx.fillEllipse(in: CGRect(x: cx + 2, y: cy + 1, width: 6, height: 8))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 6, y: cy + 3, width: 3, height: 4))
        ctx.fillEllipse(in: CGRect(x: cx + 4, y: cy + 3, width: 3, height: 4))
        ctx.setFillColor(red: 0.90, green: 0.60, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 9, width: 8, height: 5))
        ctx.setFillColor(red: 0.95, green: 0.70, blue: 0.30, alpha: 1.0)
        let flap = sin(phase * 6.0) * 3.0
        ctx.fill(CGRect(x: cx - r - 6, y: cy - 4 + flap, width: 6, height: 8))
        ctx.fill(CGRect(x: cx + r, y: cy - 4 - flap, width: 6, height: 8))
    }
}

public final class BubbleColumnWindow: NSPanel {
    public var onTap: (() -> Void)?
    private var tick: Timer?
    private var phase: CGFloat = 0
    private var drawView: BubbleColumnDrawView?

    public init(basePos: CGPoint) {
        let size = NSSize(width: 64, height: 300)
        super.init(
            contentRect: NSRect(x: basePos.x - 32, y: basePos.y, width: size.width, height: size.height),
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
        let view = BubbleColumnDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        if let tick = tick { RunLoop.main.add(tick, forMode: .common) }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BubbleColumnDrawView: NSView {
    var phase: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 0.22)
        ctx.fill(CGRect(x: 12, y: 0, width: w - 24, height: h))
        ctx.setStrokeColor(red: 0.70, green: 0.92, blue: 1.0, alpha: 0.6)
        ctx.setLineWidth(2.0)
        ctx.stroke(CGRect(x: 12, y: 1, width: w - 24, height: h - 2))
        for i in 0..<14 {
            let seed = CGFloat(i) * 47.0
            var y = seed + phase * 42.0
            y = y.truncatingRemainder(dividingBy: h)
            let x = 20 + CGFloat((i * 37) % 24)
            let r: CGFloat = 3 + CGFloat(i % 3) * 1.5
            ctx.setFillColor(red: 0.80, green: 0.95, blue: 1.0, alpha: 0.55)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
            ctx.fillEllipse(in: CGRect(x: x + 2, y: y + r, width: 2, height: 2))
        }
        ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.45, alpha: 0.9)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 8))
    }
}

public final class RainbowArchWindow: NSPanel {
    public init(centerPos: CGPoint) {
        let size = NSSize(width: 520, height: 260)
        super.init(
            contentRect: NSRect(x: centerPos.x - size.width / 2.0, y: centerPos.y, width: size.width, height: size.height),
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
        contentView = RainbowArchDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func start() {
        orderFrontRegardless()
    }
}

private final class RainbowArchDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2.0
        let colors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.95, 0.25, 0.25), (0.95, 0.60, 0.20), (0.95, 0.90, 0.30),
            (0.35, 0.80, 0.35), (0.30, 0.55, 0.95), (0.45, 0.30, 0.75), (0.70, 0.40, 0.90),
        ]
        ctx.setLineWidth(11.0)
        for (i, c) in colors.enumerated() {
            let radius: CGFloat = 220 - CGFloat(i) * 12
            ctx.setStrokeColor(red: c.0, green: c.1, blue: c.2, alpha: 0.75)
            ctx.beginPath()
            ctx.addArc(center: CGPoint(x: cx, y: 0), radius: radius, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.strokePath()
        }
    }
}

public final class RainbowPotWindow: NSPanel {
    public var onTap: (() -> Void)?
    private var sparkleTimer: Timer?
    private var phase: CGFloat = 0
    private var drawView: RainbowPotDrawView?

    public init(pos: CGPoint) {
        let size = NSSize(width: 56, height: 44)
        super.init(
            contentRect: NSRect(x: pos.x - 28, y: pos.y, width: size.width, height: size.height),
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
        let view = RainbowPotDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        sparkleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 12.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        if let sparkleTimer = sparkleTimer { RunLoop.main.add(sparkleTimer, forMode: .common) }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    public override func close() {
        sparkleTimer?.invalidate()
        sparkleTimer = nil
        super.close()
    }
}

private final class RainbowPotDrawView: NSView {
    var phase: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 22, width: 8, height: 8))
        ctx.fillEllipse(in: CGRect(x: 24, y: 26, width: 9, height: 9))
        ctx.fillEllipse(in: CGRect(x: 36, y: 22, width: 8, height: 8))
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 6, width: 36, height: 20))
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 22, width: 40, height: 5))
        let tw = 0.5 + 0.5 * sin(phase * 5.0)
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.4 + 0.6 * tw)
        ctx.fill(CGRect(x: 27, y: 32, width: 3, height: 8))
        ctx.fill(CGRect(x: 24, y: 35, width: 9, height: 3))
    }
}

public final class WaterManager {
    public static let shared = WaterManager()

    private var squid: GlowSquidWindow?
    private var puffer: PufferfishWindow?
    private var bubble: BubbleColumnWindow?
    private var bubbleCooldownUntil: Date?
    private var isSpongeWet = false
    private var spongeDryTimer: Timer?
    private var rainbowArch: RainbowArchWindow?
    private var rainbowPot: RainbowPotWindow?
    private var rainbowLifeTimer: Timer?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ [weak self] in
                (self?.squid == nil) ? "🐙 발광오징어" : "🐙 발광오징어 (보내기)"
            }, { [weak self] in self?.toggleSquid() }),
            ExtraMenuEntry({ [weak self] in
                (self?.puffer == nil) ? "🐡 복어" : "🐡 복어 (보내기)"
            }, { [weak self] in self?.togglePuffer() }),
            ExtraMenuEntry({ [weak self] in
                (self?.bubble == nil) ? "🫧 기포 기둥" : "🫧 기포 기둥 (끄기)"
            }, { [weak self] in self?.toggleBubble() }),
            ExtraMenuEntry({ [weak self] in
                (self?.isSpongeWet == true) ? "🧽 스펀지 흡수 (젖음 💧)" : "🧽 스펀지 흡수"
            }, { [weak self] in self?.absorbRain() }),
            ExtraMenuEntry({ [weak self] in
                (self?.rainbowArch == nil) ? "🌈 무지개" : "🌈 무지개 (지우기)"
            }, { [weak self] in self?.toggleRainbow() }),
        ]
    }

    private func spawnBase() -> CGPoint {
        let me = RewardCenter.me()
        if me == .zero {
            return CGPoint(x: 400, y: 200)
        }
        return CGPoint(x: me.x + 90, y: me.y)
    }

    private func toggleSquid() {
        if let w = squid {
            w.close()
            squid = nil
            return
        }
        let w = GlowSquidWindow(startPos: spawnBase())
        w.onTap = { [weak self, weak w] in
            RewardCenter.grant(xp: 2, "🦑✨ 어둠 속 길잡이! 발광 먹물 획득!")
            if let w = w { w.close() }
            self?.squid = nil
        }
        squid = w
        w.start()
        RewardCenter.say("🐙 발광오징어가 몽글몽글 떠올랐어!")
    }

    private func togglePuffer() {
        if let w = puffer {
            w.close()
            puffer = nil
            return
        }
        let w = PufferfishWindow(startPos: spawnBase())
        w.onTap = { [weak self, weak w] in
            guard let self = self, let w = w else { return }
            if w.isPuffed {
                RewardCenter.say("❤️‍🩹 퉁퉁! 독가시 조심! (🎣 낚시로 잡아봐)")
            } else {
                RewardCenter.grant(xp: 2, "🐡 복어 포획! (가만히 있을 때가 기회!)")
                w.close()
                self.puffer = nil
            }
        }
        puffer = w
        w.start()
        RewardCenter.say("🐡 복어가 쪼꼬미 헤엄쳐왔어! 가까이 가면 부풀어!")
    }

    private func toggleBubble() {
        if let w = bubble {
            w.close()
            bubble = nil
            return
        }
        let w = BubbleColumnWindow(basePos: spawnBase())
        w.onTap = { [weak self] in
            guard let self = self else { return }
            if let until = self.bubbleCooldownUntil, Date() < until {
                RewardCenter.say("🫧 기포 충전 중... 잠시만!")
                return
            }
            guard let mv = RewardCenter.movePlayer else {
                RewardCenter.say("🫧 기포가 몽글몽글! (이동 연결 없음)")
                return
            }
            let me = RewardCenter.me()
            mv(CGPoint(x: me.x, y: me.y + 200))
            self.bubbleCooldownUntil = Date().addingTimeInterval(5.0)
            RewardCenter.say("🫧 소울샌드 부글부글! 위로 뿅!")
        }
        bubble = w
        w.start()
        RewardCenter.say("🫧 기포 기둥! 클릭하면 위로 200pt 슝!")
    }

    private func absorbRain() {
        guard RewardCenter.heldItemName?() == "스펀지 🧽" else {
            RewardCenter.say("🧽 스펀지를 손에 들고 실행해줘!")
            return
        }
        if isSpongeWet {
            RewardCenter.say("🧽 스펀지가 흠뻑 젖었어... 60초 후 건조!")
            return
        }
        guard WeatherManager.shared.isRaining else {
            RewardCenter.say("🌧️ 비가 와야 흡수할 수 있어!")
            return
        }
        WeatherManager.shared.isEnabled = false
        isSpongeWet = true
        RewardCenter.grant(xp: 3, "🌧️➡️☀️ 갬! 비를 쫙 흡수했어!")
        spongeDryTimer?.invalidate()
        spongeDryTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { [weak self] t in
            t.invalidate()
            guard let self = self else { return }
            self.isSpongeWet = false
            self.spongeDryTimer = nil
            WeatherManager.shared.isEnabled = true
            RewardCenter.say("🧽 스펀지가 말랐어!")
        }
        if let spongeDryTimer = spongeDryTimer { RunLoop.main.add(spongeDryTimer, forMode: .common) }
    }

    private func toggleRainbow() {
        if rainbowArch != nil || rainbowPot != nil {
            closeRainbow()
            return
        }
        let base = spawnBase()
        let arch = RainbowArchWindow(centerPos: CGPoint(x: base.x, y: base.y))
        let potPos = CGPoint(x: base.x + 208, y: base.y)
        let pot = RainbowPotWindow(pos: potPos)
        pot.onTap = { [weak self] in
            RewardCenter.grant(xp: 5, "🌈🍯 행운의 황금단지! 대박 전리품!")
            self?.closeRainbow()
        }
        rainbowArch = arch
        rainbowPot = pot
        arch.start()
        pot.start()
        RewardCenter.say("🌈 무지개! 끝자락 단지를 클릭해봐!")
        rainbowLifeTimer?.invalidate()
        rainbowLifeTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] t in
            t.invalidate()
            self?.closeRainbow()
        }
        if let rainbowLifeTimer = rainbowLifeTimer { RunLoop.main.add(rainbowLifeTimer, forMode: .common) }
    }

    private func closeRainbow() {
        rainbowLifeTimer?.invalidate()
        rainbowLifeTimer = nil
        if let pot = rainbowPot { pot.close() }
        if let arch = rainbowArch { arch.close() }
        rainbowPot = nil
        rainbowArch = nil
    }
}
