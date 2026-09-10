import AppKit
import CoreGraphics
import Foundation

// B분야 네더 10종: 피글린·호글린·위더·비콘·마그마큐브·스트라이더·요새·영혼모래·현무암·고대잔해 + NetherBManager.
// "🎉 추가 모션" 서브메뉴에서 NetherBManager.shared.entries()로 호출한다.

public final class NetherBManager {
    public static let shared = NetherBManager()

    private var piglin: BPiglinWindow?
    private var hoglin: BHoglinWindow?
    private var wither: BWitherWindow?
    private var beacon: BBeaconWindow?
    private var magmaCubes: [BMagmaCubeWindow] = []
    private var strider: BStriderWindow?
    private var fortress: BFortressWindow?
    private var soulSand: BSoulSandWindow?
    private var basalt: BBasaltWindow?
    private var debris: BAncientDebrisWindow?

    private var hasNetherStar = false
    private var beaconBuffUntil: Date?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "👺 피글린 거래" }, { [weak self] in self?.togglePiglin() }),
            ExtraMenuEntry({ "🐗 호글린 사냥" }, { [weak self] in self?.toggleHoglin() }),
            ExtraMenuEntry({ "🟥 위더 보스전" }, { [weak self] in self?.toggleWither() }),
            ExtraMenuEntry({ "🧱 비콘" }, { [weak self] in self?.toggleBeacon() }),
            ExtraMenuEntry({ "🟧 마그마큐브" }, { [weak self] in self?.toggleMagma() }),
            ExtraMenuEntry({ "🌋 스트라이더" }, { [weak self] in self?.toggleStrider() }),
            ExtraMenuEntry({ "🏰 네더 요새" }, { [weak self] in self?.toggleFortress() }),
            ExtraMenuEntry({ "🌬️ 영혼모래" }, { [weak self] in self?.toggleSoulSand() }),
            ExtraMenuEntry({ "🪨 현무암" }, { [weak self] in self?.toggleBasalt() }),
            ExtraMenuEntry({ "⛏️ 고대 잔해" }, { [weak self] in self?.toggleDebris() }),
        ]
    }

    private func spawnPos(dx: CGFloat) -> CGPoint {
        let me = RewardCenter.me()
        if me == .zero {
            if let screen = NSScreen.main {
                let f = screen.frame
                return CGPoint(x: f.midX + dx, y: f.minY + 120)
            }
            return CGPoint(x: 400 + dx, y: 200)
        }
        return CGPoint(x: me.x + dx, y: me.y)
    }

    // MARK: - 👺 피글린: 황금 사과 들고 클릭 시 랜덤 교환 +3XP, 빈손이면 경계

    public func togglePiglin() {
        if let w = piglin, w.isVisible {
            w.close(); piglin = nil; return
        }
        piglin = nil
        let w = BPiglinWindow(startPos: spawnPos(dx: -60)) { [weak self] tapped in
            self?.handlePiglinTap(tapped)
        }
        piglin = w
        w.start()
    }

    private func handlePiglinTap(_ w: BPiglinWindow) {
        if RewardCenter.heldItemName?() == "황금 사과 🍎" {
            let loot = ["⬛ 흑요석!", "🔮 엔더 진주!", "🧨 화약!"].randomElement() ?? "⬛ 흑요석!"
            RewardCenter.grant(xp: 3, "👺 \(loot)")
            SoundAndEffectsManager.shared.play(.chime)
            w.nod()
        } else {
            RewardCenter.say("😠 ... (황금 사과가 필요해!)")
            SoundAndEffectsManager.shared.play(.alert)
            w.snort()
        }
    }

    // MARK: - 🐗 호글린: 보라 파티클 배회 + 클릭 2타 처치 돼지고기 +3XP

    public func toggleHoglin() {
        if let w = hoglin, w.isVisible {
            w.close(); hoglin = nil; return
        }
        hoglin = nil
        let w = BHoglinWindow(startPos: spawnPos(dx: 60)) { [weak self] tapped in
            self?.handleHoglinTap(tapped)
        }
        hoglin = w
        w.start()
    }

    private func handleHoglinTap(_ w: BHoglinWindow) {
        let hits = w.strike()
        if hits >= 2 {
            RewardCenter.grant(xp: 3, "🥩 호글린 돼지고기!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close()
            if hoglin === w { hoglin = nil }
        } else {
            RewardCenter.say("🐗 쿵! (1/2)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🟥 위더: 3해골+영혼모래 조합 후 보스(체력 5) + 별 +10XP

    public func toggleWither() {
        if let w = wither, w.isVisible {
            w.close(); wither = nil; return
        }
        wither = nil
        let w = BWitherWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleWitherTap(tapped)
        }
        wither = w
        w.start()
    }

    private func handleWitherTap(_ w: BWitherWindow) {
        guard w.isAwake else {
            RewardCenter.say("🟥 소환 중... (영혼모래 + 해골 3개)")
            return
        }
        let dead = w.damage()
        SoundAndEffectsManager.shared.play(.pop)
        if dead {
            hasNetherStar = true
            RewardCenter.grant(xp: 10, "⭐ 네더의 별!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close()
            if wither === w { wither = nil }
        } else {
            RewardCenter.say("🟥 쾅! (\(w.hp)/5)")
        }
    }

    // MARK: - 🧱 비콘: 별 보유 후 건설 → 피라미드 + 90초 버프, 버프 중엔 남은 시간

    public func toggleBeacon() {
        if let until = beaconBuffUntil, Date() < until {
            let left = Int(until.timeIntervalSince(Date()))
            RewardCenter.say("🧱 💨💪 버프 \(left)초 남음!")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        if beaconBuffUntil != nil {
            beaconBuffUntil = nil
            beacon?.close(); beacon = nil
        }
        guard hasNetherStar else {
            RewardCenter.say("🧱 ⭐ 네더의 별이 필요해! (위더 처치)")
            SoundAndEffectsManager.shared.play(.alert)
            return
        }
        if let w = beacon, w.isVisible {
            w.close(); beacon = nil; return
        }
        beacon = nil
        let w = BBeaconWindow(startPos: spawnPos(dx: -40))
        beacon = w
        w.start()
        beaconBuffUntil = Date().addingTimeInterval(90)
        RewardCenter.say("🧱 💨 속도·💪 힘! (90초)")
        SoundAndEffectsManager.shared.play(.chime)
    }

    // MARK: - 🟧 마그마큐브: 점프 분열(대→중→소, 최대 4) + 크림 +2XP

    public func toggleMagma() {
        let alive = magmaCubes.filter { $0.isVisible }
        if !alive.isEmpty {
            for w in alive { w.close() }
            magmaCubes.removeAll()
            return
        }
        magmaCubes.removeAll()
        spawnMagma(size: .large, pos: spawnPos(dx: 40))
    }

    private func spawnMagma(size: BMagmaSize, pos: CGPoint) {
        let w = BMagmaCubeWindow(startPos: pos, size: size) { [weak self] tapped in
            self?.handleMagmaTap(tapped)
        }
        magmaCubes.append(w)
        w.start()
    }

    private func handleMagmaTap(_ w: BMagmaCubeWindow) {
        switch w.size {
        case .large:
            let base = w.position
            closeMagma(w)
            if magmaCubes.count + 2 > 4 { return }
            spawnMagma(size: .medium, pos: CGPoint(x: base.x - 30, y: base.y))
            spawnMagma(size: .medium, pos: CGPoint(x: base.x + 30, y: base.y))
            RewardCenter.say("🟧 분열!")
            SoundAndEffectsManager.shared.play(.pop)
        case .medium:
            let base = w.position
            closeMagma(w)
            if magmaCubes.count + 2 > 4 {
                RewardCenter.grant(xp: 2, "🔥 마그마 크림!")
                SoundAndEffectsManager.shared.play(.chime)
                return
            }
            spawnMagma(size: .small, pos: CGPoint(x: base.x - 20, y: base.y))
            spawnMagma(size: .small, pos: CGPoint(x: base.x + 20, y: base.y))
            RewardCenter.say("🟧 분열!")
            SoundAndEffectsManager.shared.play(.pop)
        case .small:
            closeMagma(w)
            RewardCenter.grant(xp: 2, "🔥 마그마 크림!")
            SoundAndEffectsManager.shared.play(.chime)
        }
    }

    private func closeMagma(_ w: BMagmaCubeWindow) {
        w.close()
        magmaCubes.removeAll { $0 === w }
    }

    // MARK: - 🌋 스트라이더: 하단 배회 + 클릭 탑승 토글 + 용암 걷기

    public func toggleStrider() {
        if let w = strider, w.isVisible {
            w.close(); strider = nil; return
        }
        strider = nil
        let w = BStriderWindow(startPos: spawnPos(dx: 80)) { [weak self] tapped in
            self?.handleStriderTap(tapped)
        }
        strider = w
        w.start()
    }

    private func handleStriderTap(_ w: BStriderWindow) {
        let riding = w.toggleRide()
        if riding {
            RewardCenter.say("🌋 첨벙! 용암 위를 걸어!")
            SoundAndEffectsManager.shared.play(.splash)
        } else {
            RewardCenter.say("🌋 내려!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🏰 네더 요새: 던전 입구 + 방 3개 순차 탐험 + 위더해골 +4XP

    public func toggleFortress() {
        if let w = fortress, w.isVisible {
            w.close(); fortress = nil; return
        }
        fortress = nil
        let w = BFortressWindow(startPos: spawnPos(dx: -80)) { [weak self] tapped in
            self?.handleFortressTap(tapped)
        }
        fortress = w
        w.start()
    }

    private func handleFortressTap(_ w: BFortressWindow) {
        let room = w.explore()
        if room >= 3 {
            RewardCenter.grant(xp: 4, "💀 위더 해골!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close()
            if fortress === w { fortress = nil }
        } else {
            RewardCenter.say("🏰 \(room + 1)/3방 탐험 중...")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🌬️ 영혼모래: 바닥 타일 1개 + 클릭 시 3초 🐌 + 해제

    public func toggleSoulSand() {
        if let w = soulSand, w.isVisible {
            w.close(); soulSand = nil; return
        }
        soulSand = nil
        let w = BSoulSandWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleSoulSandTap(tapped)
        }
        soulSand = w
        w.start()
    }

    private func handleSoulSandTap(_ w: BSoulSandWindow) {
        if w.isSlowed {
            RewardCenter.say("🌬️ 🐌 아직 느려!")
            return
        }
        w.snare()
        RewardCenter.say("🌬️ 🐌 발이 묶였다! (3초)")
        SoundAndEffectsManager.shared.play(.splash)
    }

    // MARK: - 🪨 현무암: 하얀 연기 10초 이벤트 + 관상 +1XP

    public func toggleBasalt() {
        if let w = basalt, w.isVisible {
            w.close(); basalt = nil; return
        }
        basalt = nil
        let w = BBasaltWindow(startPos: spawnPos(dx: -20)) { [weak self] tapped in
            self?.handleBasaltTap(tapped)
        }
        basalt = w
        w.start()
    }

    private func handleBasaltTap(_ w: BBasaltWindow) {
        if w.collect() {
            RewardCenter.grant(xp: 1, "🪨 현무암 관상!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("🪨 ...")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - ⛏️ 고대 잔해: 곡괭이 10회 채굴 → 네더라이트 +6XP, 맨손은 힌트

    public func toggleDebris() {
        if let w = debris, w.isVisible {
            w.close(); debris = nil; return
        }
        debris = nil
        let w = BAncientDebrisWindow(startPos: spawnPos(dx: 20)) { [weak self] tapped in
            self?.handleDebrisTap(tapped)
        }
        debris = w
        w.start()
    }

    private func handleDebrisTap(_ w: BAncientDebrisWindow) {
        if RewardCenter.heldItemName?() == "다이아몬드 곡괭이 ⛏️" {
            let n = w.mine()
            SoundAndEffectsManager.shared.play(.pop)
            if n >= 10 {
                RewardCenter.grant(xp: 6, "🪙 네더라이트!")
                SoundAndEffectsManager.shared.play(.chime)
                w.close()
                if debris === w { debris = nil }
            } else {
                RewardCenter.say("⛏️ \(n)/10 채굴 중...")
            }
        } else {
            RewardCenter.say("⛏️ \(w.progress)/10 (다이아 곡괭이가 필요해!)")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }
}

// MARK: - 👺 피글린

public final class BPiglinWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (BPiglinWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var mood: TimeInterval = 0
    private var drawView: BPiglinDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (BPiglinWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BPiglinDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.mood > 0 { self.mood -= 1.0 / 60.0 }
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 20.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.happy = self.mood > 0
            self.drawView?.bob = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func nod() { mood = 1.2 }
    public func snort() { mood = 0 }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BPiglinDrawView: NSView {
    var facingRight = true
    var happy = false
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.95, green: 0.72, blue: 0.62, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 10 + bob, width: 30, height: 30))
        ctx.fillEllipse(in: CGRect(x: 20, y: 36 + bob, width: 26, height: 14))
        ctx.setFillColor(red: 0.98, green: 0.82, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 44 + bob, width: 22, height: 5))
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 27, y: 30 + bob, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 37, y: 30 + bob, width: 4, height: 4))
        if happy {
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 50, y: 12, width: 8, height: 8))
        }
        ctx.setFillColor(red: 0.88, green: 0.62, blue: 0.52, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 2, width: 8, height: 12))
        ctx.fill(CGRect(x: 46, y: 2, width: 8, height: 12))
        ctx.restoreGState()
    }
}

// MARK: - 🐗 호글린

public final class BHoglinWindow: NSPanel {
    public var position: CGPoint
    public private(set) var hits = 0
    private let onTap: (BHoglinWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var drawView: BHoglinDrawView?
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (BHoglinWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BHoglinDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 3 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 34.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.phase = self.phase
            self.drawView?.hits = self.hits
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func strike() -> Int {
        hits += 1
        drawView?.needsDisplay = true
        return hits
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BHoglinDrawView: NSView {
    var facingRight = true
    var phase: TimeInterval = 0
    var hits = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        let bob = sin(phase * 4.0)
        ctx.setFillColor(red: 0.80, green: 0.45, blue: 0.40, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 12 + bob, width: 52, height: 28))
        ctx.fillEllipse(in: CGRect(x: 54, y: 20 + bob, width: 18, height: 16))
        ctx.setFillColor(red: 0.95, green: 0.90, blue: 0.85, alpha: 1.0)
        ctx.fill(CGRect(x: 62, y: 14 + bob, width: 4, height: 10))
        ctx.fill(CGRect(x: 68, y: 14 + bob, width: 4, height: 10))
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 61, y: 27 + bob, width: 3, height: 3))
        ctx.setFillColor(red: 0.55, green: 0.30, blue: 0.28, alpha: 1.0)
        for x in [16, 28, 44, 54] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 8, height: 12))
        }
        if hits > 0 {
            ctx.setFillColor(red: 1.0, green: 0.25, blue: 0.20, alpha: 0.9)
            ctx.fill(CGRect(x: 30, y: 44, width: 4, height: 8))
        }
        ctx.setFillColor(red: 0.65, green: 0.30, blue: 0.85, alpha: 0.55)
        for i in 0..<5 {
            let px = 6 + CGFloat(i) * 16 + CGFloat(sin(phase * 3.0 + Double(i))) * 4
            ctx.fillEllipse(in: CGRect(x: px, y: 46, width: 5, height: 5))
        }
        ctx.restoreGState()
    }
}

// MARK: - 🟥 위더

public final class BWitherWindow: NSPanel {
    public var position: CGPoint
    public private(set) var hp = 5
    public private(set) var isAwake = false
    private let onTap: (BWitherWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var combineLeft: TimeInterval = 2.0
    private var burst: TimeInterval = 0
    private var drawView: BWitherDrawView?
    private let panelW: CGFloat = 96
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, onTap: @escaping (BWitherWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BWitherDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.burst > 0 { self.burst -= 1.0 / 60.0 }
            if !self.isAwake {
                self.combineLeft -= 1.0 / 60.0
                if self.combineLeft <= 0 {
                    self.isAwake = true
                    SoundAndEffectsManager.shared.play(.alert)
                }
            } else {
                self.position.y += sin(self.phase * 2.0) * 8.0 / 60.0
                self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            }
            self.drawView?.phase = self.phase
            self.drawView?.awake = self.isAwake
            self.drawView?.hp = self.hp
            self.drawView?.burst = self.burst > 0
            self.drawView?.combine = max(0, self.combineLeft)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func damage() -> Bool {
        guard isAwake else { return false }
        hp -= 1
        burst = 0.3
        return hp <= 0
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BWitherDrawView: NSView {
    var phase: TimeInterval = 0
    var awake = false
    var hp = 5
    var burst = false
    var combine: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let floatY = sin(phase * 2.0) * 3.0
        if !awake {
            ctx.setFillColor(red: 0.30, green: 0.22, blue: 0.18, alpha: 1.0)
            ctx.fill(CGRect(x: 28, y: 4, width: 40, height: 12))
            ctx.setFillColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
            let spread = CGFloat(combine) * 10.0
            for i in 0..<3 {
                ctx.fillEllipse(in: CGRect(x: 30 + CGFloat(i) * 16, y: 20 + spread, width: 12, height: 12))
            }
            return
        }
        ctx.setFillColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 28, y: 22 + floatY, width: 40, height: 34))
        ctx.setFillColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 32, y: 40 + floatY, width: 12, height: 12))
        ctx.fillEllipse(in: CGRect(x: 52, y: 40 + floatY, width: 12, height: 12))
        ctx.fillEllipse(in: CGRect(x: 42, y: 34 + floatY, width: 12, height: 12))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        for x in [35, 55, 45] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: x, y: 43 + floatY, width: 4, height: 5))
        }
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0)
        ctx.fill(CGRect(x: 44, y: 4, width: 8, height: 22))
        for i in 0..<hp {
            ctx.setFillColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: 24 + CGFloat(i) * 10, y: 62, width: 8, height: 6))
        }
        if burst {
            ctx.setFillColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.8)
            ctx.fillEllipse(in: CGRect(x: 20, y: 14, width: 56, height: 44))
        }
    }
}

// MARK: - 🧱 비콘

public final class BBeaconWindow: NSPanel {
    public var position: CGPoint
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: BBeaconDrawView?
    private let panelW: CGFloat = 96
    private let panelH: CGFloat = 96

    public init(startPos: CGPoint) {
        self.position = startPos
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BBeaconDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BBeaconDrawView: NSView {
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.50, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 2, width: 60, height: 8))
        ctx.fill(CGRect(x: 28, y: 10, width: 40, height: 8))
        ctx.setFillColor(red: 0.35, green: 0.75, blue: 0.65, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 38, y: 20, width: 20, height: 16))
        let glow = 0.55 + 0.25 * CGFloat(sin(phase * 4.0))
        ctx.setFillColor(red: 0.55, green: 0.90, blue: 1.0, alpha: glow)
        ctx.fill(CGRect(x: 45, y: 36, width: 6, height: 56))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        ctx.fill(CGRect(x: 46, y: 36, width: 4, height: 56))
    }
}

// MARK: - 🟧 마그마큐브

public enum BMagmaSize: Int {
    case small = 0
    case medium = 1
    case large = 2
}

public final class BMagmaCubeWindow: NSPanel {
    public var position: CGPoint
    public let size: BMagmaSize
    private let onTap: (BMagmaCubeWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: BMagmaCubeDrawView?
    private let panelW: CGFloat
    private let panelH: CGFloat

    public init(startPos: CGPoint, size: BMagmaSize, onTap: @escaping (BMagmaCubeWindow) -> Void) {
        self.position = startPos
        self.size = size
        self.onTap = onTap
        switch size {
        case .large: panelW = 72; panelH = 64
        case .medium: panelW = 52; panelH = 46
        case .small: panelW = 34; panelH = 30
        }
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BMagmaCubeDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)), size: size)
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            let hop = abs(sin(self.phase * 5.0)) * 14.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hop))
            self.drawView?.hop = hop
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BMagmaCubeDrawView: NSView {
    var hop: CGFloat = 0
    private let size: BMagmaSize

    init(frame: NSRect, size: BMagmaSize) {
        self.size = size
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let squash: CGFloat = hop > 2 ? 1.0 : 0.82
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.85, green: 0.35, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 2, width: w - 4, height: (h - 4) * squash))
        ctx.setFillColor(red: 1.0, green: 0.75, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w * 0.2, y: h * 0.3, width: w * 0.25, height: h * 0.25))
        ctx.fillEllipse(in: CGRect(x: w * 0.55, y: h * 0.35, width: w * 0.25, height: h * 0.25))
        ctx.setFillColor(red: 0.15, green: 0.10, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w * 0.28, y: h * 0.38, width: 4, height: 5))
        ctx.fillEllipse(in: CGRect(x: w * 0.63, y: h * 0.43, width: 4, height: 5))
        _ = size
    }
}

// MARK: - 🌋 스트라이더

public final class BStriderWindow: NSPanel {
    public var position: CGPoint
    public private(set) var isRidden = false
    private let onTap: (BStriderWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var drawView: BStriderDrawView?
    private let panelW: CGFloat = 76
    private let panelH: CGFloat = 52

    public init(startPos: CGPoint, onTap: @escaping (BStriderWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BStriderDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            let speed: CGFloat = self.isRidden ? 52 : 22
            self.position.x += self.dir * speed / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.phase = self.phase
            self.drawView?.ridden = self.isRidden
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func toggleRide() -> Bool {
        isRidden.toggle()
        return isRidden
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BStriderDrawView: NSView {
    var facingRight = true
    var phase: TimeInterval = 0
    var ridden = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        let step = sin(phase * 6.0) * 2.0
        ctx.setFillColor(red: 1.0, green: 0.35, blue: 0.15, alpha: 0.55)
        ctx.fillEllipse(in: CGRect(x: 2, y: 0, width: 72, height: 10))
        ctx.setFillColor(red: 0.75, green: 0.20, blue: 0.18, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 14, y: 12, width: 44, height: 24))
        ctx.fillEllipse(in: CGRect(x: 52, y: 20, width: 16, height: 14))
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 57, y: 25, width: 4, height: 4))
        ctx.setFillColor(red: 0.55, green: 0.12, blue: 0.12, alpha: 1.0)
        for x in [20, 32, 44] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2 + (step > 0 ? step : 0), width: 6, height: 12))
        }
        if ridden {
            ctx.setFillColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 34, width: 14, height: 10))
        }
        ctx.restoreGState()
    }
}

// MARK: - 🏰 네더 요새

public final class BFortressWindow: NSPanel {
    public var position: CGPoint
    public private(set) var room = 0
    private let onTap: (BFortressWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: BFortressDrawView?
    private let panelW: CGFloat = 104
    private let panelH: CGFloat = 84

    public init(startPos: CGPoint, onTap: @escaping (BFortressWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BFortressDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.phase = self.phase
            self.drawView?.room = self.room
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func explore() -> Int {
        room = min(3, room + 1)
        drawView?.needsDisplay = true
        return room
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BFortressDrawView: NSView {
    var phase: TimeInterval = 0
    var room = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.25, green: 0.15, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 20, width: 20, height: 56))
        ctx.fill(CGRect(x: 80, y: 20, width: 20, height: 56))
        ctx.fill(CGRect(x: 4, y: 64, width: 96, height: 14))
        ctx.setFillColor(red: 0.08, green: 0.05, blue: 0.07, alpha: 1.0)
        ctx.fill(CGRect(x: 40, y: 20, width: 24, height: 40))
        let flicker = 0.7 + 0.3 * CGFloat(sin(phase * 5.0))
        ctx.setFillColor(red: 1.0, green: 0.6, blue: 0.15, alpha: flicker)
        ctx.fillEllipse(in: CGRect(x: 12, y: 66, width: 6, height: 6))
        ctx.fillEllipse(in: CGRect(x: 86, y: 66, width: 6, height: 6))
        for i in 0..<3 {
            if i < room {
                ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.35, green: 0.30, blue: 0.32, alpha: 1.0)
            }
            ctx.fillEllipse(in: CGRect(x: 30 + CGFloat(i) * 16, y: 6, width: 12, height: 12))
        }
    }
}

// MARK: - 🌬️ 영혼모래

public final class BSoulSandWindow: NSPanel {
    public var position: CGPoint
    public private(set) var slowLeft: TimeInterval = 0
    public var isSlowed: Bool { slowLeft > 0 }
    private let onTap: (BSoulSandWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: BSoulSandDrawView?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 32

    public init(startPos: CGPoint, onTap: @escaping (BSoulSandWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BSoulSandDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.slowLeft > 0 {
                self.slowLeft -= 1.0 / 60.0
                if self.slowLeft <= 0 {
                    self.slowLeft = 0
                    RewardCenter.say("🌬️ 💨 해제!")
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
            self.drawView?.phase = self.phase
            self.drawView?.slowed = self.slowLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func snare() {
        slowLeft = 3.0
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BSoulSandDrawView: NSView {
    var phase: TimeInterval = 0
    var slowed = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.32, green: 0.24, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 2, width: bounds.width - 4, height: bounds.height - 4))
        ctx.setFillColor(red: 0.55, green: 0.70, blue: 0.75, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: 14, y: 10, width: 12, height: 10))
        ctx.fillEllipse(in: CGRect(x: 40, y: 12, width: 10, height: 8))
        ctx.fillEllipse(in: CGRect(x: 28, y: 6, width: 8, height: 7))
        if slowed {
            let pulse = 0.35 + 0.2 * CGFloat(sin(phase * 6.0))
            ctx.setFillColor(red: 0.45, green: 0.75, blue: 1.0, alpha: pulse)
            ctx.fill(CGRect(x: 2, y: 2, width: bounds.width - 4, height: bounds.height - 4))
        }
    }
}

// MARK: - 🪨 현무암

public final class BBasaltWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (BBasaltWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var lifeLeft: TimeInterval = 10.0
    private var cooldown: TimeInterval = 0
    private var drawView: BBasaltDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, onTap: @escaping (BBasaltWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BBasaltDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.cooldown > 0 { self.cooldown -= 1.0 / 60.0 }
            self.lifeLeft -= 1.0 / 60.0
            if self.lifeLeft <= 0 {
                self.close()
                return
            }
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func collect() -> Bool {
        guard cooldown <= 0 else { return false }
        cooldown = 3.0
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BBasaltDrawView: NSView {
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 2, width: 36, height: 34))
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 8, width: 8, height: 22))
        ctx.fill(CGRect(x: 36, y: 8, width: 8, height: 22))
        for i in 0..<4 {
            let rise = fmod(phase * 22.0 + Double(i) * 14.0, 44.0)
            let alpha = 0.55 * (1.0 - rise / 44.0)
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alpha)
            let w: CGFloat = 16 - CGFloat(rise) * 0.2
            ctx.fillEllipse(in: CGRect(x: 32 - w / 2 + CGFloat(sin(phase * 2.0 + Double(i))) * 3, y: 36 + CGFloat(rise), width: w, height: w * 0.7))
        }
    }
}

// MARK: - ⛏️ 고대 잔해

public final class BAncientDebrisWindow: NSPanel {
    public var position: CGPoint
    public private(set) var progress = 0
    private let onTap: (BAncientDebrisWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var shake: TimeInterval = 0
    private var drawView: BAncientDebrisDrawView?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (BAncientDebrisWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH),
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
        let view = BAncientDebrisDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.shake > 0 { self.shake -= 1.0 / 60.0 }
            let dx = self.shake > 0 ? CGFloat(sin(self.phase * 40.0)) * 2.0 : 0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2 + dx, y: self.position.y))
            self.drawView?.progress = self.progress
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func mine() -> Int {
        progress = min(10, progress + 1)
        shake = 0.25
        drawView?.needsDisplay = true
        return progress
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class BAncientDebrisDrawView: NSView {
    var progress = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.30, green: 0.22, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 12, width: 52, height: 34))
        ctx.setFillColor(red: 0.55, green: 0.32, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 22, width: 20, height: 14))
        ctx.setStrokeColor(red: 0.15, green: 0.10, blue: 0.11, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.stroke(CGRect(x: 10, y: 12, width: 52, height: 34))
        let cracks = min(10, progress)
        if cracks > 0 {
            ctx.setStrokeColor(red: 0.10, green: 0.08, blue: 0.08, alpha: 0.9)
            ctx.setLineWidth(1.5)
            for i in 0..<cracks {
                let y = 14 + CGFloat(i) * 3.0
                ctx.move(to: CGPoint(x: 14, y: y))
                ctx.addLine(to: CGPoint(x: 58, y: y + 1.5))
                ctx.strokePath()
            }
        }
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 2, width: 52, height: 6))
        ctx.setFillColor(red: 0.95, green: 0.70, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 2, width: 52 * CGFloat(progress) / 10.0, height: 6))
    }
}
