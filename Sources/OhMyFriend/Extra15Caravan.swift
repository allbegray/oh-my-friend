import AppKit
import CoreGraphics

// 15차 백로그: 사막 캐러밴 5종(낙타·라마·행상인·선인장·사원함정) + CaravanManager.

// MARK: - 낙타

private final class CaravanCamelDrawView: NSView {
    var riding = false
    var facingRight = true
    var bob: CGFloat = 0
    var dust: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        if riding {
            ctx.setFillColor(red: 0.85, green: 0.82, blue: 0.75, alpha: 0.9)
            for i in 0..<4 {
                let dx = 2 + CGFloat(i) * 7 + dust.truncatingRemainder(dividingBy: 8)
                let dy = 4 + CGFloat((i * 5 + Int(dust)) % 8)
                ctx.fillEllipse(in: CGRect(x: dx, y: dy, width: 5, height: 4))
            }
        }
        // 몸통 (2단 높이)
        ctx.setFillColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 22 + bob, width: 52, height: 26))
        // 혹
        ctx.setFillColor(red: 0.70, green: 0.53, blue: 0.36, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30, y: 44 + bob, width: 22, height: 14))
        // 긴 목 + 머리
        ctx.setFillColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: 58, y: 40 + bob, width: 10, height: 30))
        ctx.fill(CGRect(x: 54, y: 64 + bob, width: 20, height: 12))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 68, y: 68 + bob, width: 3, height: 4))
        // 다리 4개
        ctx.setFillColor(red: 0.68, green: 0.52, blue: 0.36, alpha: 1.0)
        for x in [18, 28, 48, 58] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 6, height: 22))
        }
        // 탑승 안장 표시
        if riding {
            ctx.setFillColor(red: 0.75, green: 0.20, blue: 0.20, alpha: 1.0)
            ctx.fill(CGRect(x: 32, y: 48 + bob, width: 18, height: 6))
            ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.50, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 38, y: 56 + bob, width: 8, height: 8))
        }
        ctx.restoreGState()
    }
}

private final class CaravanCamelWindow: NSPanel {
    private var position: CGPoint
    private var riding = false
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var drawView: CaravanCamelDrawView?

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 84, height: 84)
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
        let view = CaravanCamelDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase * 60.0) % 240 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            let speed: CGFloat = self.riding ? 60.0 : 30.0
            self.position.x += self.dir * speed / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 42, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * (self.riding ? 8.0 : 4.0))
            self.drawView?.riding = self.riding
            self.drawView?.dust = CGFloat(self.phase * 30.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func mouseDown(with event: NSEvent) {
        riding.toggle()
        drawView?.riding = riding
        drawView?.needsDisplay = true
        if riding {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🐪 히야!")
            if RewardCenter.friendPos?() != nil {
                RewardCenter.say("👥 동승!")
            }
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

// MARK: - 라마

private final class CaravanLlamaDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0
    var carpet = 0
    var spitting = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통
        ctx.setFillColor(red: 0.87, green: 0.80, blue: 0.70, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 16 + bob, width: 40, height: 22))
        // 목 + 머리
        ctx.fill(CGRect(x: 46, y: 30 + bob, width: 9, height: 26))
        ctx.fill(CGRect(x: 43, y: 52 + bob, width: 17, height: 11))
        // 귀
        ctx.fill(CGRect(x: 45, y: 62 + bob, width: 4, height: 7))
        ctx.fill(CGRect(x: 52, y: 62 + bob, width: 4, height: 7))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 54, y: 56 + bob, width: 3, height: 4))
        // 카펫 (빨강/파랑/초록)
        switch carpet {
        case 0: ctx.setFillColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1.0)
        case 1: ctx.setFillColor(red: 0.20, green: 0.35, blue: 0.80, alpha: 1.0)
        default: ctx.setFillColor(red: 0.25, green: 0.65, blue: 0.30, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 18, y: 28 + bob, width: 24, height: 14))
        // 다리
        ctx.setFillColor(red: 0.78, green: 0.70, blue: 0.60, alpha: 1.0)
        for x in [16, 24, 38, 46] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 5, height: 16))
        }
        // 침 뱉기
        if spitting {
            ctx.setFillColor(red: 0.45, green: 0.75, blue: 0.40, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 62, y: 50 + bob, width: 6, height: 5))
            ctx.fillEllipse(in: CGRect(x: 70, y: 48 + bob, width: 4, height: 4))
            ctx.fillEllipse(in: CGRect(x: 77, y: 46 + bob, width: 3, height: 3))
        }
        ctx.restoreGState()
    }
}

private final class CaravanLlamaWindow: NSPanel {
    private var position: CGPoint
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var nextSpit: TimeInterval = 6.0
    private var spitUntil: TimeInterval = 0
    private var drawView: CaravanLlamaDrawView?

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 88, height: 72)
        super.init(
            contentRect: NSRect(x: startPos.x - 44, y: startPos.y, width: size.width, height: size.height),
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
        let view = CaravanLlamaDrawView(frame: NSRect(origin: .zero, size: size))
        view.carpet = Int.random(in: 0..<3)
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase * 60.0) % 240 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 26.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - 44, y: self.position.y))
            if self.phase >= self.nextSpit {
                self.spitUntil = self.phase + 1.0
                self.nextSpit = self.phase + TimeInterval.random(in: 8.0...15.0)
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.say("💦 퉤!")
            }
            let spitting = self.phase < self.spitUntil
            self.drawView?.spitting = spitting
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.bob = sin(self.phase * 4.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func mouseDown(with event: NSEvent) {
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.grant(xp: 1, "❤️")
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

// MARK: - 행상인

private final class CaravanTraderDrawView: NSView {
    var bob: CGFloat = 0
    var hasLlama = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 행상인 몸
        ctx.setFillColor(red: 0.30, green: 0.35, blue: 0.80, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 14 + bob, width: 24, height: 30))
        // 머리
        ctx.setFillColor(red: 0.90, green: 0.75, blue: 0.60, alpha: 1.0)
        ctx.fill(CGRect(x: 33, y: 44 + bob, width: 18, height: 16))
        // 모자
        ctx.setFillColor(red: 0.45, green: 0.25, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 58 + bob, width: 24, height: 6))
        // 가방
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 54, y: 20 + bob, width: 12, height: 16))
        if hasLlama {
            ctx.setFillColor(red: 0.87, green: 0.80, blue: 0.70, alpha: 1.0)
            ctx.fill(CGRect(x: 4, y: 8, width: 22, height: 16))
            ctx.fill(CGRect(x: 20, y: 18, width: 7, height: 18))
            ctx.fill(CGRect(x: 18, y: 34, width: 12, height: 8))
        }
    }
}

private final class CaravanTraderWindow: NSPanel {
    private var position: CGPoint
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var traded = false
    private var drawView: CaravanTraderDrawView?

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 76, height: 68)
        super.init(
            contentRect: NSRect(x: startPos.x - 38, y: startPos.y, width: size.width, height: size.height),
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
        let view = CaravanTraderDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(timer!, forMode: .common)
        // 50% 확률로 귀가
        if Bool.random() {
            RewardCenter.say("🧳 오늘은 장사 안 해!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.close()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showTradeAlert()
            }
        }
    }

    private func showTradeAlert() {
        guard isVisible else { return }
        let alert = NSAlert()
        alert.messageText = "🧳 행상인"
        alert.informativeText = "이국적인 물건을 가져왔네! 하나 골라보게."
        alert.addButton(withTitle: "발광열매")
        alert.addButton(withTitle: "안장")
        alert.addButton(withTitle: "화살통")
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn || resp == .alertSecondButtonReturn || resp == .alertThirdButtonReturn {
            if !traded {
                traded = true
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.grant(xp: 3, "🤑 득템!")
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        showTradeAlert()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

// MARK: - 선인장 화분

private final class CaravanCactusDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 화분
        ctx.setFillColor(red: 0.65, green: 0.35, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 2, width: 32, height: 16))
        ctx.setFillColor(red: 0.55, green: 0.28, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 16, width: 36, height: 5))
        // 선인장 몸
        ctx.setFillColor(red: 0.25, green: 0.65, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 21, width: 16, height: 32))
        ctx.fill(CGRect(x: 14, y: 30, width: 8, height: 14))
        ctx.fill(CGRect(x: 38, y: 34, width: 8, height: 12))
        // 가시 픽셀아트
        ctx.setFillColor(red: 0.90, green: 0.95, blue: 0.85, alpha: 1.0)
        for y in stride(from: 24, through: 50, by: 5) {
            ctx.fill(CGRect(x: 20, y: CGFloat(y), width: 3, height: 1))
            ctx.fill(CGRect(x: 37, y: CGFloat(y), width: 3, height: 1))
        }
        for x in stride(from: 24, through: 34, by: 5) {
            ctx.fill(CGRect(x: CGFloat(x), y: 40, width: 1, height: 3))
        }
    }
}

private final class CaravanCactusWindow: NSPanel {
    init(startPos: CGPoint) {
        let size = NSSize(width: 60, height: 58)
        super.init(
            contentRect: NSRect(x: startPos.x - 30, y: startPos.y, width: size.width, height: size.height),
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
        contentView = CaravanCactusDrawView(frame: NSRect(origin: .zero, size: size))
    }

    func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    override func mouseDown(with event: NSEvent) {
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🌵 따끔!")
    }
}

// MARK: - 사원 함정

private final class CaravanTempleDrawView: NSView {
    var fuseBlink = false
    var exploded = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if exploded {
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 0.95)
            ctx.fillEllipse(in: CGRect(x: 8, y: 4, width: 84, height: 60))
            ctx.setFillColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 24, y: 14, width: 52, height: 38))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 0.40, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 40, y: 24, width: 20, height: 18))
            return
        }
        // 사막 사원 입구
        ctx.setFillColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 18, width: 88, height: 40))
        ctx.setFillColor(red: 0.75, green: 0.63, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 52, width: 88, height: 8))
        // 입구
        ctx.setFillColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 38, y: 18, width: 24, height: 30))
        // 압력판
        if fuseBlink {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.70, green: 0.55, blue: 0.35, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 40, y: 6, width: 20, height: 8))
        // 황금 장식
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 44, width: 8, height: 8))
        ctx.fill(CGRect(x: 78, y: 44, width: 8, height: 8))
    }
}

private final class CaravanTempleWindow: NSPanel {
    private var fuseTimer: Timer?
    private var fuseElapsed: TimeInterval = 0
    private var used = false
    private var drawView: CaravanTempleDrawView?

    init(startPos: CGPoint) {
        let size = NSSize(width: 100, height: 64)
        super.init(
            contentRect: NSRect(x: startPos.x - 50, y: startPos.y, width: size.width, height: size.height),
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
        let view = CaravanTempleDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    override func mouseDown(with event: NSEvent) {
        guard !used else { return }
        used = true
        fuseElapsed = 0
        SoundAndEffectsManager.shared.play(.pop)
        fuseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.fuseElapsed += 0.15
            self.drawView?.fuseBlink.toggle()
            self.drawView?.needsDisplay = true
            if self.fuseElapsed >= 2.0 {
                t.invalidate()
                self.fuseTimer = nil
                self.explode()
            }
        }
        RunLoop.main.add(fuseTimer!, forMode: .common)
    }

    private func explode() {
        drawView?.exploded = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("💥 펑!")
        RewardCenter.grant(xp: 6, "🏺 황금 보상!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.close()
        }
    }

    override func close() {
        fuseTimer?.invalidate()
        fuseTimer = nil
        super.close()
    }
}

// MARK: - CaravanManager

public final class CaravanManager {
    public static let shared = CaravanManager()
    private init() {}

    private var camel: CaravanCamelWindow?
    private var llama: CaravanLlamaWindow?
    private var trader: CaravanTraderWindow?
    private var cacti: [CaravanCactusWindow] = []
    private var temple: CaravanTempleWindow?

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🐪 낙타 타기" }, { [weak self] in self?.spawnCamel() }),
            ExtraMenuEntry({ "🦙 라마 쓰다듬기" }, { [weak self] in self?.spawnLlama() }),
            ExtraMenuEntry({ "🧳 행상인 거래" }, { [weak self] in self?.spawnTrader() }),
            ExtraMenuEntry({ "🌵 선인장 화분" }, { [weak self] in self?.placeCactus() }),
            ExtraMenuEntry({ "🏺 사원 발굴" }, { [weak self] in self?.spawnTemple() }),
        ]
    }

    private func spawnCamel() {
        camel?.close()
        let base = RewardCenter.me()
        let w = CaravanCamelWindow(startPos: CGPoint(x: base.x + 120, y: base.y))
        camel = w
        w.start()
    }

    private func spawnLlama() {
        llama?.close()
        let base = RewardCenter.me()
        let w = CaravanLlamaWindow(startPos: CGPoint(x: base.x - 120, y: base.y))
        llama = w
        w.start()
    }

    private func spawnTrader() {
        trader?.close()
        let base = RewardCenter.me()
        let w = CaravanTraderWindow(startPos: CGPoint(x: base.x + 60, y: base.y + 40))
        trader = w
        w.start()
    }

    private func placeCactus() {
        let base = RewardCenter.me()
        let offset = CGFloat(cacti.count * 56)
        let w = CaravanCactusWindow(startPos: CGPoint(x: base.x - 80 - offset, y: base.y))
        w.place()
        cacti.append(w)
        while cacti.count > 3 {
            let old = cacti.removeFirst()
            old.close()
        }
    }

    private func spawnTemple() {
        temple?.close()
        let base = RewardCenter.me()
        let w = CaravanTempleWindow(startPos: CGPoint(x: base.x, y: base.y + 80))
        temple = w
        w.start()
    }
}
