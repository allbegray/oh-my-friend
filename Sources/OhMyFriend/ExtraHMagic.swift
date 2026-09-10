import AppKit
import CoreGraphics
import Foundation

// H분야 마법/인챈트 백로그 10종: 네더라이트·채널링·메이스·윈드차지·잔류형·스플래시·저주·행운·수선·경험치농장 + MagicHManager.
// AppController "🎉 추가 모션" 서브메뉴에서 MagicHManager.shared.entries()로 호출한다.
// 장비/삼지창/곡괭이/낙하감지 등 엔진 접근 불가 요소는 클릭 의식·연출·자체 상태로 대체한다.

public final class MagicHManager {
    public static let shared = MagicHManager()

    private let netherite = ToggleSlot<HNetheriteWindow>()
    private let channeling = ToggleSlot<HChannelingWindow>()
    private let mace = ToggleSlot<HMaceWindow>()
    private let wind = ToggleSlot<HWindChargeWindow>()
    private let lingering = ToggleSlot<HLingeringZoneWindow>()
    private let splash = ToggleSlot<HSplashPotionWindow>()
    private let curse = ToggleSlot<HCurseWindow>()
    private let lucky = ToggleSlot<HLuckyOreWindow>()
    private let mending = ToggleSlot<HMendingWindow>()
    private let farm = ToggleSlot<HXpFarmWindow>()
    private var mendingBank = 20

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "⬛ 네더라이트 강화" }, { [weak self] in self?.toggleNetherite() }),
            ExtraMenuEntry({ "⚡ 채널링" }, { [weak self] in self?.toggleChanneling() }),
            ExtraMenuEntry({ "🔨 메이스" }, { [weak self] in self?.toggleMace() }),
            ExtraMenuEntry({ "💨 윈드 차지" }, { [weak self] in self?.toggleWind() }),
            ExtraMenuEntry({ "🧪 잔류형 물약" }, { [weak self] in self?.toggleLingering() }),
            ExtraMenuEntry({ "💥 스플래시" }, { [weak self] in self?.toggleSplash() }),
            ExtraMenuEntry({ "📜 저주" }, { [weak self] in self?.toggleCurse() }),
            ExtraMenuEntry({ "🍀 행운 채굴" }, { [weak self] in self?.toggleLucky() }),
            ExtraMenuEntry({ "✨ 수선" }, { [weak self] in self?.toggleMending() }),
            ExtraMenuEntry({ "🌾 경험치 농장" }, { [weak self] in self?.toggleFarm() }),
        ]
    }

    private func spawnPos(dx: CGFloat) -> CGPoint {
        let me = RewardCenter.me()
        if me == .zero {
            if let screen = NSScreen.main {
                let f = screen.frame
                return CGPoint(x: f.midX + dx, y: f.minY + 140)
            }
            return CGPoint(x: 400 + dx, y: 220)
        }
        return CGPoint(x: me.x + dx, y: me.y + 20)
    }

    // MARK: - 1 네더라이트: 대장간 패널 + 클릭 3회 강화 의식 +4XP

    public func toggleNetherite() {
        netherite.toggle(make: {
            HNetheriteWindow(floorPos: self.spawnPos(dx: -80)) { [weak self] in
                RewardCenter.grant(xp: 4, "⬛ 네더라이트 업그레이드!")
                SoundAndEffectsManager.shared.play(.chime)
                self?.netherite.clear()
            }
        }, start: { $0.place() })
    }

    // MARK: - 2 채널링: 번개 연출 + 과녁 클릭 직격 판정 +5XP

    public func toggleChanneling() {
        channeling.toggle(make: {
            HChannelingWindow(floorPos: self.spawnPos(dx: 80)) { [weak self] hit in
                if hit {
                    RewardCenter.grant(xp: 5, "⚡ 채널링 직격!")
                    SoundAndEffectsManager.shared.play(.alert)
                } else {
                    RewardCenter.say("⚡ 빗나갔다...")
                    SoundAndEffectsManager.shared.play(.pop)
                }
                self?.channeling.clear()
            }
        }, start: { $0.place() })
    }

    // MARK: - 3 메이스: 클릭 점프(상승→강하) + 높이 게이지 + 밀도/파열 2지선다

    public func toggleMace() {
        mace.toggle(make: {
            HMaceWindow(floorPos: self.spawnPos(dx: 0)) { smashed, damage in
                if smashed {
                    RewardCenter.grant(xp: 3, "🔨 스매시! \(damage)뎀!")
                    SoundAndEffectsManager.shared.play(.alert)
                }
            }
        }, start: { $0.place() })
    }

    // MARK: - 4 윈드 차지: 클릭당 +80pt 공중 점프, 최대 3단, 쿨 3초

    public func toggleWind() {
        wind.toggle(make: {
            HWindChargeWindow(floorPos: self.spawnPos(dx: 0)) {
                let me = RewardCenter.me()
                guard me != .zero else { return false }
                RewardCenter.movePlayer?(CGPoint(x: me.x, y: me.y + 80))
                return true
            }
        }, start: { $0.place() })
    }

    // MARK: - 5 잔류형: 30초 범위 존 + 존 안 클릭 버프

    public func toggleLingering() {
        lingering.toggle(make: {
            HLingeringZoneWindow(floorPos: self.spawnPos(dx: 0)) {
                RewardCenter.say("🧪 잔류 버프!")
                SoundAndEffectsManager.shared.play(.gulp)
            }
        }, start: { [weak self] w in
            w.place()
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.lingering.clear()
            }
        })
    }

    // MARK: - 6 스플래시: 포물선 미니병 + 범위 적용 단체 버프

    public func toggleSplash() {
        splash.toggle(make: {
            HSplashPotionWindow(floorPos: self.spawnPos(dx: 0)) {
                RewardCenter.grant(xp: 2, "💥 스플래시 단체 버프!")
                SoundAndEffectsManager.shared.play(.splash)
            }
        }, start: { $0.place() })
    }

    // MARK: - 7 저주: 결박(갑옷 emoji 고정 기분) + 소멸 경고 + 스릴 +2XP

    public func toggleCurse() {
        curse.toggle(make: {
            HCurseWindow(floorPos: self.spawnPos(dx: 0)) { step in
                if step == 0 {
                    RewardCenter.grant(xp: 2, "📜 결박의 저주... ⛓️ 갑옷 고정!")
                    SoundAndEffectsManager.shared.play(.alert)
                } else {
                    RewardCenter.say("📜 소멸의 저주... 죽으면 사라진다!")
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
        }, start: { $0.place() })
    }

    // MARK: - 8 행운: 광석 5회 채굴(2배 드롭 확률) + 실크터치 모드

    public func toggleLucky() {
        lucky.toggle(make: {
            HLuckyOreWindow(floorPos: self.spawnPos(dx: 0)) { [weak self] mined, doubled, finished in
                let silk = RewardCenter.heldItemName?().contains("실크") ?? false
                if silk {
                    RewardCenter.say("🍀 실크터치! 원석 그대로!")
                    SoundAndEffectsManager.shared.play(.pop)
                    return
                }
                if doubled {
                    RewardCenter.grant(xp: 2, "🍀 행운 2배 드롭! (\(mined)/5)")
                } else {
                    RewardCenter.say("⛏️ 채굴! (\(mined)/5)")
                }
                SoundAndEffectsManager.shared.play(.chime)
                if finished {
                    RewardCenter.grant(xp: 2, "🍀 광석 완파!")
                    self?.lucky.clear()
                }
            }
        }, start: { $0.place() })
    }

    // MARK: - 9 수선: 자체 XP 뱅크에서 5 소모 후 수리 완료

    public func toggleMending() {
        mending.toggle(make: {
            HMendingWindow(floorPos: self.spawnPos(dx: 0), bank: { [weak self] in self?.mendingBank ?? 0 }) { [weak self] done in
                guard let self = self else { return }
                if self.mendingBank >= 5 {
                    self.mendingBank -= 5
                    RewardCenter.say("✨ 수선 완료! (뱅크 \(self.mendingBank))")
                    SoundAndEffectsManager.shared.play(.chime)
                    done(true, self.mendingBank)
                } else {
                    RewardCenter.say("✨ XP 부족! (뱅크 \(self.mendingBank))")
                    SoundAndEffectsManager.shared.play(.pop)
                    done(false, self.mendingBank)
                }
            }
        }, start: { $0.place() })
    }

    // MARK: - 10 경험치 농장: 자체 몹 3마리 순환 + 10초당 +1XP 최대 10회 자동 흡수

    public func toggleFarm() {
        farm.toggle(make: {
            HXpFarmWindow(floorPos: self.spawnPos(dx: 0)) { [weak self] count in
                RewardCenter.grant(xp: 1, "🌾 농장 흡수 (\(count)/10)")
                SoundAndEffectsManager.shared.play(.pop)
                if count >= 10 {
                    self?.farm.clear()
                }
            }
        }, start: { $0.place() })
    }
}

// MARK: - 1 네더라이트 대장간 패널 (클릭 3회 의식)

public final class HNetheriteWindow: EntityWindow {
    private let onUpgrade: () -> Void
    private var rites = HitCounter(maxHits: 3)
    private var drawView: HNetheriteDrawView?
    private let panelW: CGFloat = 128
    private let panelH: CGFloat = 96

    public init(floorPos: CGPoint, onUpgrade: @escaping () -> Void) {
        self.onUpgrade = onUpgrade
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HNetheriteDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        let done = rites.hit()
        drawView?.rites = rites.hits
        drawView?.needsDisplay = true
        if !done {
            RewardCenter.say("⬛ 강화 의식... (\(rites.hits)/3)")
            SoundAndEffectsManager.shared.play(.pop)
        } else {
            onUpgrade()
        }
    }
}

private final class HNetheriteDrawView: NSView {
    var rites = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 8, width: bounds.width - 16, height: 30))
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 34, width: bounds.width - 16, height: 8))
        let frac = CGFloat(rites) / 3.0
        ctx.setFillColor(red: 0.45, green: 0.85, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 52, width: 88 * (1 - frac), height: 12))
        ctx.setFillColor(red: 0.25, green: 0.22, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: 20 + 88 * (1 - frac), y: 52, width: 88 * frac, height: 12))
        if rites >= 3 {
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: bounds.width / 2 - 6, y: 70, width: 12, height: 12))
        }
        for i in 0..<3 {
            if i < rites {
                ctx.setFillColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1.0)
            }
            ctx.fillEllipse(in: CGRect(x: 44 + CGFloat(i) * 16, y: 14, width: 10, height: 10))
        }
    }
}

// MARK: - 2 채널링 번개 + 과녁 (클릭 직격 판정)

public final class HChannelingWindow: EntityWindow {
    private let onStrike: (Bool) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: HChannelingDrawView?
    private let panelW: CGFloat = 110
    private let panelH: CGFloat = 150

    public init(floorPos: CGPoint, onStrike: @escaping (Bool) -> Void) {
        self.onStrike = onStrike
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HChannelingDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = event.locationInWindow
        let cx: CGFloat = panelW / 2
        let dx = loc.x - cx
        let dy = loc.y - 26
        let hit = (dx * dx + dy * dy) < 24 * 24
        drawView?.flashed = true
        drawView?.needsDisplay = true
        onStrike(hit)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class HChannelingDrawView: NSView {
    var phase: TimeInterval = 0
    var flashed = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let on = flashed || (sin(phase * 14.0) > -0.2)
        if on {
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.55, green: 0.60, blue: 0.95, alpha: 0.7)
        }
        let cx = bounds.width / 2
        ctx.fill(CGRect(x: cx - 4, y: 70, width: 8, height: 60))
        ctx.fill(CGRect(x: cx - 12, y: 96, width: 16, height: 8))
        ctx.fill(CGRect(x: cx - 4, y: 78, width: 16, height: 8))
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 24, y: 2, width: 48, height: 48))
        ctx.setFillColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 16, y: 10, width: 32, height: 32))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 8, y: 18, width: 16, height: 16))
    }
}

// MARK: - 3 메이스 (클릭 상승→강하 + 게이지 + 밀도/파열 교대)

public final class HMaceWindow: EntityWindow {
    private let onSmash: (Bool, Int) -> Void
    private var tick: Timer?
    private var anim: TimeInterval = -1
    private var taps = 0
    private var drawView: HMaceDrawView?
    private let panelW: CGFloat = 100
    private let panelH: CGFloat = 120

    public init(floorPos: CGPoint, onSmash: @escaping (Bool, Int) -> Void) {
        self.onSmash = onSmash
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HMaceDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        taps += 1
        anim = 0
        tick?.invalidate()
        let burst = taps % 2 == 0
        let damage = 3 * 3 + (burst ? 4 : 2)
        drawView?.heightLevel = 3
        drawView?.burstMode = burst
        drawView?.needsDisplay = true
        RewardCenter.say(burst ? "🔨 파열! 공중 폭발!" : "🔨 밀도! 묵직한 일격!")
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.anim += 1.0 / 60.0
            if self.anim < 0.25 {
                self.drawView?.lift = CGFloat(self.anim / 0.25) * 44
            } else if self.anim < 0.5 {
                self.drawView?.lift = 44 - CGFloat((self.anim - 0.25) / 0.25) * 44
            } else {
                t.invalidate()
                self.tick = nil
                self.anim = -1
                self.drawView?.lift = 0
                self.drawView?.heightLevel = 0
                self.drawView?.needsDisplay = true
                self.onSmash(true, damage)
                return
            }
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

private final class HMaceDrawView: NSView {
    var lift: CGFloat = 0
    var heightLevel = 0
    var burstMode = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        for i in 0..<3 {
            if i < heightLevel {
                ctx.setFillColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 0.6)
            }
            ctx.fill(CGRect(x: 6, y: 10 + CGFloat(i) * 16, width: 10, height: 12))
        }
        let y = 30 + lift
        if burstMode {
            ctx.setFillColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1.0)
        }
        ctx.fillEllipse(in: CGRect(x: 38, y: y + 22, width: 26, height: 22))
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 48, y: y, width: 6, height: 24))
        if lift < 4 && heightLevel > 0 {
            ctx.setStrokeColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 0.9)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: 26, y: 4, width: 50, height: 14))
        }
    }
}

// MARK: - 4 윈드 차지 (클릭당 +80pt, 3단 후 3초 쿨)

public final class HWindChargeWindow: EntityWindow {
    private let onJump: () -> Bool
    private var jumpsUsed = 0
    private var cooldown = Cooldown()
    private var drawView: HWindChargeDrawView?

    public init(floorPos: CGPoint, onJump: @escaping () -> Bool) {
        self.onJump = onJump
        let size = NSSize(width: 72, height: 72)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = HWindChargeDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        if !cooldown.ready {
            RewardCenter.say("💨 쿨타임...")
            return
        }
        guard jumpsUsed < 3 else { return }
        if onJump() {
            jumpsUsed += 1
            drawView?.jumpsUsed = jumpsUsed
            drawView?.cooling = false
            drawView?.needsDisplay = true
            RewardCenter.say("💨 윈드 차지! (\(jumpsUsed)/3단)")
            SoundAndEffectsManager.shared.play(.pop)
            if jumpsUsed >= 3 {
                cooldown.trigger(3.0)
                drawView?.cooling = true
                drawView?.needsDisplay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.jumpsUsed = 0
                    self?.cooldown.tick(3.0)
                    self?.drawView?.jumpsUsed = 0
                    self?.drawView?.cooling = false
                    self?.drawView?.needsDisplay = true
                }
            }
        }
    }
}

private final class HWindChargeDrawView: NSView {
    var jumpsUsed = 0
    var cooling = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.85, green: 0.95, blue: 1.0, alpha: cooling ? 0.4 : 0.95)
        ctx.fillEllipse(in: CGRect(x: 18, y: 18, width: 36, height: 36))
        ctx.setStrokeColor(red: 0.4, green: 0.65, blue: 0.9, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.strokeEllipse(in: CGRect(x: 22, y: 22, width: 28, height: 28))
        for i in 0..<3 {
            if i < (3 - jumpsUsed) {
                ctx.setFillColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 0.5)
            }
            ctx.fillEllipse(in: CGRect(x: 20 + CGFloat(i) * 14, y: 6, width: 9, height: 9))
        }
    }
}

// MARK: - 5 잔류형 물약 범위 존 (30초, 존 안 클릭 버프)

public final class HLingeringZoneWindow: EntityWindow {
    private let onBuff: () -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: HLingeringDrawView?
    private let panelW: CGFloat = 220
    private let panelH: CGFloat = 120

    public init(floorPos: CGPoint, onBuff: @escaping () -> Void) {
        self.onBuff = onBuff
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HLingeringDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onBuff()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class HLingeringDrawView: NSView {
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let pulse = 0.55 + 0.2 * sin(phase * 3.0)
        ctx.setFillColor(red: 0.6, green: 0.2, blue: 0.7, alpha: pulse)
        ctx.fillEllipse(in: CGRect(x: 10, y: 6, width: bounds.width - 20, height: bounds.height - 12))
        ctx.setFillColor(red: 0.75, green: 0.45, blue: 0.9, alpha: 0.5)
        for i in 0..<6 {
            let x = 30 + CGFloat(i) * 30 + CGFloat(sin(phase * 2.0 + Double(i))) * 4
            let y = 40 + CGFloat(cos(phase * 1.6 + Double(i) * 1.3)) * 18
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: 7, height: 7))
        }
    }
}

// MARK: - 6 스플래시 투척 (포물선 미니병 + 범위 적용)

public final class HSplashPotionWindow: EntityWindow {
    private let onSplash: () -> Void
    private var tick: Timer?
    private var t: TimeInterval = 0
    private var splashed = false
    private var drawView: HSplashDrawView?
    private let panelW: CGFloat = 180
    private let panelH: CGFloat = 110

    public init(floorPos: CGPoint, onSplash: @escaping () -> Void) {
        self.onSplash = onSplash
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HSplashDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        t = 0
        splashed = false
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.t += 1.0 / 60.0
            let k = min(1.0, self.t / 0.7)
            self.drawView?.flight = k
            self.drawView?.splashed = k >= 1.0
            self.drawView?.needsDisplay = true
            if k >= 1.0 && !self.splashed {
                self.splashed = true
                timer.invalidate()
                self.tick = nil
                self.onSplash()
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        place()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class HSplashDrawView: NSView {
    var flight: Double = 0
    var splashed = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if !splashed {
            let x0: CGFloat = 16
            let x1: CGFloat = bounds.width - 24
            let x = x0 + (x1 - x0) * CGFloat(flight)
            let y = 70 - CGFloat(flight * flight) * 30 + CGFloat(flight) * 10
            ctx.setFillColor(red: 0.55, green: 0.25, blue: 0.75, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: y, width: 12, height: 14))
            ctx.setFillColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
            ctx.fill(CGRect(x: x + 3, y: y + 14, width: 6, height: 5))
        } else {
            ctx.setFillColor(red: 0.6, green: 0.3, blue: 0.8, alpha: 0.55)
            ctx.fillEllipse(in: CGRect(x: bounds.width / 2 - 55, y: 8, width: 110, height: 60))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
            for i in 0..<5 {
                let x = bounds.width / 2 - 40 + CGFloat(i) * 18
                ctx.fillEllipse(in: CGRect(x: x, y: 30, width: 6, height: 6))
            }
        }
    }
}

// MARK: - 7 저주 (결박→소멸 클릭 진행)

public final class HCurseWindow: EntityWindow {
    private let onStep: (Int) -> Void
    private var steps = 0
    private var drawView: HCurseDrawView?
    private let panelW: CGFloat = 110
    private let panelH: CGFloat = 90

    public init(floorPos: CGPoint, onStep: @escaping (Int) -> Void) {
        self.onStep = onStep
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HCurseDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
    }

    public override func mouseDown(with event: NSEvent) {
        onStep(min(steps, 1))
        steps += 1
        drawView?.steps = steps
        drawView?.needsDisplay = true
    }
}

private final class HCurseDrawView: NSView {
    var steps = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 14, width: 50, height: 60))
        ctx.setFillColor(red: 0.90, green: 0.82, blue: 0.66, alpha: 1.0)
        ctx.fill(CGRect(x: 34, y: 18, width: 42, height: 52))
        ctx.setFillColor(red: 0.65, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 44, y: 46, width: 22, height: 3))
        ctx.fill(CGRect(x: 48, y: 38, width: 14, height: 3))
        if steps >= 1 {
            ctx.setStrokeColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
            ctx.setLineWidth(3.0)
            ctx.move(to: CGPoint(x: 20, y: 70))
            ctx.addLine(to: CGPoint(x: 90, y: 20))
            ctx.strokePath()
        }
        if steps >= 2 {
            ctx.setStrokeColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0)
            ctx.setLineWidth(4.0)
            ctx.move(to: CGPoint(x: 30, y: 80))
            ctx.addLine(to: CGPoint(x: 80, y: 10))
            ctx.move(to: CGPoint(x: 80, y: 80))
            ctx.addLine(to: CGPoint(x: 30, y: 10))
            ctx.strokePath()
        }
    }
}

// MARK: - 8 행운 광석 (5회 채굴, 2배 드롭 확률)

public final class HLuckyOreWindow: EntityWindow {
    private let onMine: (Int, Bool, Bool) -> Void
    private var mined = HitCounter(maxHits: 5)
    private var drawView: HLuckyOreDrawView?
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 84

    public init(floorPos: CGPoint, onMine: @escaping (Int, Bool, Bool) -> Void) {
        self.onMine = onMine
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HLuckyOreDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        guard mined.hits < 5 else { return }
        let finished = mined.hit()
        let doubled = Double.random(in: 0..<1) < 0.5
        drawView?.mined = mined.hits
        drawView?.needsDisplay = true
        onMine(mined.hits, doubled, finished)
    }
}

private final class HLuckyOreDrawView: NSView {
    var mined = 0
    var lastDoubled = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let frac = 1.0 - CGFloat(mined) / 5.0
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 10, width: 56, height: 56 * frac + 8))
        ctx.setFillColor(red: 0.45, green: 0.85, blue: 0.95, alpha: 1.0)
        let gems = max(0, 3 - mined / 2)
        for i in 0..<gems {
            ctx.fill(CGRect(x: 22 + CGFloat(i) * 16, y: 30, width: 9, height: 9))
        }
        ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1.0)
        for i in 0..<mined {
            ctx.fill(CGRect(x: 14 + CGFloat(i) * 12, y: 66, width: 8, height: 4))
        }
        if lastDoubled && mined < 5 {
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.35, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: bounds.width - 24, y: bounds.height - 22, width: 12, height: 12))
        }
    }
}

// MARK: - 9 수선 모루 (자체 XP 뱅크 5 소모)

public final class HMendingWindow: EntityWindow {
    private let bank: () -> Int
    private let onRepair: (@escaping (Bool, Int) -> Void) -> Void
    private var drawView: HMendingDrawView?
    private let panelW: CGFloat = 120
    private let panelH: CGFloat = 84

    public init(floorPos: CGPoint, bank: @escaping () -> Int, onRepair: @escaping (@escaping (Bool, Int) -> Void) -> Void) {
        self.bank = bank
        self.onRepair = onRepair
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HMendingDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
        drawView?.bank = bank()
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        onRepair({ [weak self] ok, left in
            self?.drawView?.repaired = ok
            self?.drawView?.bank = left
            self?.drawView?.needsDisplay = true
        })
    }
}

private final class HMendingDrawView: NSView {
    var repaired = false
    var bank = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 26, width: 88, height: 16))
        ctx.fill(CGRect(x: 44, y: 8, width: 32, height: 18))
        if repaired {
            ctx.setFillColor(red: 0.75, green: 0.90, blue: 1.0, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.70, green: 0.55, blue: 0.40, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 52, y: 42, width: 8, height: 30))
        if repaired {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 0.6, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 66, y: 58, width: 10, height: 10))
            ctx.fillEllipse(in: CGRect(x: 40, y: 50, width: 7, height: 7))
        }
    }
}

// MARK: - 10 경험치 농장 (몹 3마리 순환 + 10초당 자동 흡수 최대 10회)

public final class HXpFarmWindow: EntityWindow {
    private let onAbsorb: (Int) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var absorbed = 0
    private var acc: TimeInterval = 0
    private var drawView: HXpFarmDrawView?
    private let panelW: CGFloat = 170
    private let panelH: CGFloat = 90

    public init(floorPos: CGPoint, onAbsorb: @escaping (Int) -> Void) {
        self.onAbsorb = onAbsorb
        super.init(contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = HXpFarmDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 30.0
            self.phase += dt
            self.acc += dt
            if self.acc >= 10.0 && self.absorbed < 10 {
                self.acc = 0
                self.absorbed += 1
                self.onAbsorb(self.absorbed)
            }
            self.drawView?.phase = self.phase
            self.drawView?.absorbed = self.absorbed
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        RewardCenter.say("🌾 몹 3마리 순환 중... (\(absorbed)/10)")
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class HXpFarmDrawView: NSView {
    var phase: TimeInterval = 0
    var absorbed = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 30, width: 34, height: 34))
        ctx.setFillColor(red: 0.35, green: 0.60, blue: 1.0, alpha: 0.85)
        ctx.fill(CGRect(x: 44, y: 34, width: 116, height: 12))
        ctx.setFillColor(red: 0.35, green: 0.80, blue: 0.35, alpha: 1.0)
        for i in 0..<3 {
            let k = fmod(phase * 0.25 + Double(i) / 3.0, 1.0)
            let x = 50 + CGFloat(k) * 100
            ctx.fillEllipse(in: CGRect(x: x, y: 48, width: 12, height: 12))
        }
        for i in 0..<10 {
            if i < absorbed {
                ctx.setFillColor(red: 0.55, green: 1.0, blue: 0.45, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 0.5)
            }
            ctx.fill(CGRect(x: 10 + CGFloat(i) * 15, y: 8, width: 12, height: 10))
        }
    }
}
