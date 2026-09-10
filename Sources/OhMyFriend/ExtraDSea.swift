import AppKit
import CoreGraphics
import Foundation

// D분야 바다 10종: 엘더가디언·가디언·돌고래·난파선·산호초·켈프·바다랜턴·조개·심해잠수·낚시대회 + SeaDManager.
// SeaDManager.shared.entries()로 메뉴 연결한다.

public final class SeaDManager {
    public static let shared = SeaDManager()

    private var elder: DElderGuardianWindow?
    private var guardian: DGuardianWindow?
    private var dolphin: DDolphinWindow?
    private let wreckSlot = ToggleSlot<DShipwreckWindow>()
    private let coralSlot = ToggleSlot<DCoralWindow>()
    private var kelp: DKelpWindow?
    private var lantern: DSeaLanternWindow?
    private var clam: DClamWindow?

    private var diveChest: DDiveChestWindow?
    private var diveLeft: TimeInterval = 0
    private var diveTimer: Timer?

    private var dolphinBuffLeft: TimeInterval = 0
    private var dolphinBuffTimer: Timer?

    private var contestWin: DFishingContestWindow?
    private var contestLeft: TimeInterval = 0
    private var contestTimer: Timer?
    private var contestBiggest: CGFloat = 0

    private var contestActive: Bool { contestWin?.isVisible == true }

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "👁️ 엘더가디언" }, { [weak self] in self?.toggleElder() }),
            ExtraMenuEntry({ "🐡 가디언" }, { [weak self] in self?.toggleGuardian() }),
            ExtraMenuEntry({ "🐬 돌고래" }, { [weak self] in self?.toggleDolphin() }),
            ExtraMenuEntry({ "🚢 난파선" }, { [weak self] in self?.toggleWreck() }),
            ExtraMenuEntry({ "🪸 산호초" }, { [weak self] in self?.toggleCoral() }),
            ExtraMenuEntry({ "🌿 켈프" }, { [weak self] in self?.toggleKelp() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🏮 바다 랜턴" }
                return self.isNightNow() ? "🏮 바다 랜턴 ✨" : "🏮 바다 랜턴"
            }, { [weak self] in self?.toggleLantern() }),
            ExtraMenuEntry({ "🐚 조개" }, { [weak self] in self?.toggleClam() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🤿 심해 잠수" }
                if self.diveLeft > 0 { return "🤿 심해 잠수 (\(Int(self.diveLeft))초)" }
                return "🤿 심해 잠수"
            }, { [weak self] in self?.toggleDive() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🎣 낚시 대회" }
                if self.contestActive {
                    let m = Int(self.contestLeft) / 60
                    let s = Int(self.contestLeft) % 60
                    return "🎣 낚시 대회 (\(m):\(String(format: "%02d", s)) · 최대 \(Int(self.contestBiggest))cm)"
                }
                return "🎣 낚시 대회"
            }, { [weak self] in self?.toggleContest() }),
        ]
    }

    // MARK: - 엘더가디언: 대형 눈 보스 + 20초 저주 + 클릭 4타 격퇴 +8XP

    public func toggleElder() {
        if let w = elder, w.isVisible { w.close(); elder = nil; return }
        elder = nil
        let w = DElderGuardianWindow(startPos: spawnPos(dx: -80)) { [weak self] tapped in
            self?.handleElderTap(tapped)
        }
        elder = w
        w.start()
        RewardCenter.say("👁️ 고대의 눈이 널 노려본다…!")
    }

    private func handleElderTap(_ w: DElderGuardianWindow) {
        let hits = w.registerHit()
        if w.isDefeated {
            RewardCenter.grant(xp: 8, "👁️ 엘더가디언 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); elder = nil
            return
        }
        if w.curseLeft > 0 {
            RewardCenter.say("🐌 엘더의 저주! (\(hits)/4)")
            SoundAndEffectsManager.shared.play(.alert)
        } else {
            RewardCenter.say("👁️ 맞았다! (\(hits)/4)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 가디언: 3초 레이저 조준선 + 발사 넉백 + 클릭 2타 +4XP

    public func toggleGuardian() {
        if let w = guardian, w.isVisible { w.close(); guardian = nil; return }
        guardian = nil
        let w = DGuardianWindow(startPos: spawnPos(dx: 80)) { [weak self] tapped in
            self?.handleGuardianTap(tapped)
        }
        guardian = w
        w.start()
        RewardCenter.say("🐡 가디언이 레이저를 충전한다!")
    }

    private func handleGuardianTap(_ w: DGuardianWindow) {
        if w.registerHit() {
            RewardCenter.grant(xp: 4, "🐡 가디언 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); guardian = nil
        } else {
            RewardCenter.say("🐡 가디언에게 금이 갔다! (1/2)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 돌고래: 플레이어 추종 + 60pt 내 호위 + 5분 버프 +2XP

    public func toggleDolphin() {
        if let w = dolphin, w.isVisible {
            w.close(); dolphin = nil
            stopDolphinBuff()
            return
        }
        dolphin = nil
        let w = DDolphinWindow(startPos: spawnPos(dx: 0)) { [weak self] _ in
            self?.handleDolphinTap()
        }
        dolphin = w
        w.start()
        startDolphinBuff()
        RewardCenter.grant(xp: 2, "🐬 돌고래가 호위에 나섰다! (+30% 기분)")
        SoundAndEffectsManager.shared.play(.splash)
    }

    private func handleDolphinTap() {
        guard let w = dolphin else { return }
        if w.isEscorting {
            RewardCenter.say("🐬💨 쌩쌩! 기분 최고!")
            SoundAndEffectsManager.shared.play(.heart)
        } else {
            RewardCenter.say("🐬 삐익!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    private func startDolphinBuff() {
        stopDolphinBuff()
        dolphinBuffLeft = 300
        dolphinBuffTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.dolphinBuffLeft -= 1.0
            if self.dolphinBuffLeft <= 0 {
                self.stopDolphinBuff()
                RewardCenter.say("🐬 돌고래 버프 종료!")
            }
        }
        if let t = dolphinBuffTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func stopDolphinBuff() {
        dolphinBuffTimer?.invalidate()
        dolphinBuffTimer = nil
        dolphinBuffLeft = 0
    }

    // MARK: - 난파선: 상자 3개 + 지도 조각 3개 = 보물 힌트 +5XP

    public func toggleWreck() {
        let pos = spawnPos(dx: -120)
        wreckSlot.toggle(make: {
            DShipwreckWindow(startPos: pos) { [weak self] tapped in
                self?.handleWreckTap(tapped)
            }
        }, start: { $0.start() })
        RewardCenter.say("🚢 난파선을 발견했다! 상자를 열어보자!")
    }

    private func handleWreckTap(_ w: DShipwreckWindow) {
        let res = w.openNext()
        if res.finished {
            RewardCenter.grant(xp: 5, "🗺️ 지도 완성! 보물은 동쪽 모래섬 밑!")
            SoundAndEffectsManager.shared.play(.chime)
            return
        }
        RewardCenter.say("🗺️ 지도 조각 \(res.pieces)/3!")
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - 산호초: 5색 순환 파밍 + 완성 시 염료 세트 +4XP

    public func toggleCoral() {
        let pos = spawnPos(dx: 120)
        coralSlot.toggle(make: {
            DCoralWindow(startPos: pos) { [weak self] tapped in
                self?.handleCoralTap(tapped)
            }
        }, start: { $0.start() })
        RewardCenter.say("🪸 산호를 클릭해 5색을 모아보자!")
    }

    private func handleCoralTap(_ w: DCoralWindow) {
        let res = w.collectNext()
        if res.completed {
            RewardCenter.grant(xp: 4, "🎨 염료 세트 완성!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("\(res.colorName) 산호 획득! (\(res.count)/5)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 켈프: 5초/단계 5단계 고속 성장 + 말린 켈프 +2XP

    public func toggleKelp() {
        if let w = kelp, w.isVisible { w.close(); kelp = nil; return }
        kelp = nil
        let w = DKelpWindow(startPos: spawnPos(dx: -40)) { [weak self] tapped in
            self?.handleKelpTap(tapped)
        }
        kelp = w
        w.start()
        RewardCenter.say("🌿 켈프를 심었다! 쑥쑥 자란다!")
    }

    private func handleKelpTap(_ w: DKelpWindow) {
        if w.tryHarvest() {
            RewardCenter.grant(xp: 2, "🌿 말린 켈프 냠!")
            SoundAndEffectsManager.shared.play(.gulp)
        } else {
            RewardCenter.say("🌿 자라는 중… (\(w.stage)/5)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 바다 랜턴: 밤(18~06시) 자동 점등 + 설치/해체

    public func toggleLantern() {
        if let w = lantern, w.isVisible { w.close(); lantern = nil; return }
        lantern = nil
        let w = DSeaLanternWindow(startPos: spawnPos(dx: 40)) { [weak self] tapped in
            self?.handleLanternTap(tapped)
        }
        lantern = w
        w.start()
        if isNightNow() {
            RewardCenter.say("🏮 바다 랜턴이 밤바다를 밝힌다!")
        } else {
            RewardCenter.say("🏮 바다 랜턴 설치! 밤이 되면 켜진다!")
        }
    }

    private func handleLanternTap(_ w: DSeaLanternWindow) {
        if w.isLit {
            RewardCenter.say("🏮 따뜻하다…")
            SoundAndEffectsManager.shared.play(.heart)
        } else {
            RewardCenter.say("🏮 낮에는 충전 중! (밤 18~06시 점등)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    private func isNightNow() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 18 || h < 6
    }

    // MARK: - 조개: 클릭 시 30% 진주 +3XP / 꽝 모래

    public func toggleClam() {
        if let w = clam, w.isVisible { w.close(); clam = nil; return }
        clam = nil
        let w = DClamWindow(startPos: spawnPos(dx: -160)) { [weak self] tapped in
            self?.handleClamTap(tapped)
        }
        clam = w
        w.start()
        RewardCenter.say("🐚 조개를 열어보자! 진주가 있을까?")
    }

    private func handleClamTap(_ w: DClamWindow) {
        if Double.random(in: 0..<1) < 0.30 {
            w.setOpened(pearl: true)
            RewardCenter.grant(xp: 3, "🤍 진주 발견!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            w.setOpened(pearl: false)
            RewardCenter.say("🐚 꽝! 모래뿐…")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 심해 잠수: 호흡 버프 60초 + 심해 상자 1개 +4XP

    public func toggleDive() {
        if diveLeft > 0 || diveChest?.isVisible == true {
            stopDive()
            RewardCenter.say("🤿 잠수 종료!")
            return
        }
        diveLeft = 60
        diveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.diveLeft -= 1.0
            if self.diveLeft <= 0 {
                self.stopDive()
                RewardCenter.say("🤿 호흡 버프 종료! 푸하!")
            }
        }
        if let t = diveTimer { RunLoop.main.add(t, forMode: .common) }
        let c = DDiveChestWindow(startPos: spawnPos(dx: 160)) { [weak self] in
            self?.handleDiveChest()
        }
        diveChest = c
        c.start()
        RewardCenter.say("🤿 호흡 버프 60초! 심해 상자를 수확하자!")
        SoundAndEffectsManager.shared.play(.splash)
    }

    private func handleDiveChest() {
        guard let c = diveChest, c.isVisible else { return }
        if c.harvest() {
            RewardCenter.grant(xp: 4, "🧰 심해 상자 수확!")
            SoundAndEffectsManager.shared.play(.chime)
            c.close(); diveChest = nil
        }
    }

    private func stopDive() {
        diveTimer?.invalidate()
        diveTimer = nil
        diveLeft = 0
        if let c = diveChest, c.isVisible { c.close() }
        diveChest = nil
    }

    // MARK: - 낚시 대회: 5분 타이머 + 클릭 낚시 + 최대어 기록 + 종료 순위 +6XP

    public func toggleContest() {
        if contestActive {
            finishContest(early: true)
            return
        }
        contestBiggest = 0
        contestLeft = 300
        let w = DFishingContestWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleContestTap(tapped)
        }
        contestWin = w
        w.start()
        contestTimer?.invalidate()
        contestTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.contestLeft -= 1.0
            self.contestWin?.timeLeft = max(0, self.contestLeft)
            if self.contestLeft <= 0 { self.finishContest(early: false) }
        }
        if let t = contestTimer { RunLoop.main.add(t, forMode: .common) }
        RewardCenter.say("🎣 낚시 대회 시작! 5분 안에 최대어를 노려라!")
        SoundAndEffectsManager.shared.play(.splash)
    }

    private func handleContestTap(_ w: DFishingContestWindow) {
        let size = CGFloat.random(in: 10...150)
        if size > contestBiggest { contestBiggest = size }
        w.lastCatch = size
        if size >= 120 {
            RewardCenter.say("🎣 대어! \(Int(size))cm!")
            SoundAndEffectsManager.shared.play(.chime)
        } else if size >= 60 {
            RewardCenter.say("🐟 \(Int(size))cm!")
            SoundAndEffectsManager.shared.play(.pop)
        } else {
            RewardCenter.say("🐟 피라미 \(Int(size))cm…")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    private func finishContest(early: Bool) {
        contestTimer?.invalidate()
        contestTimer = nil
        let rank: String
        if contestBiggest >= 120 { rank = "🥇 금메달!" }
        else if contestBiggest >= 60 { rank = "🥈 은메달!" }
        else if contestBiggest > 0 { rank = "🥉 참가상!" }
        else { rank = "🎣 노피시…" }
        if let w = contestWin, w.isVisible { w.close() }
        contestWin = nil
        contestLeft = 0
        let tail = early ? " (조기 종료)" : ""
        RewardCenter.grant(xp: 6, "🎣 대회 종료\(tail)! 최대어 \(Int(contestBiggest))cm \(rank)")
        SoundAndEffectsManager.shared.play(.chime)
        contestBiggest = 0
    }

    // MARK: - 공통

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
}

// MARK: - 👁️ 엘더가디언: 대형 눈 보스 + 20초 저주

public final class DElderGuardianWindow: EntityWindow {
    public var position: CGPoint
    private var counter = HitCounter(maxHits: 4)
    public private(set) var hits: Int = 0
    public private(set) var curseLeft: TimeInterval = 20
    public var isDefeated: Bool { hits >= 4 }
    private let onTap: (DElderGuardianWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: DElderDrawView?
    private let panelW: CGFloat = 110
    private let panelH: CGFloat = 84

    public init(startPos: CGPoint, onTap: @escaping (DElderGuardianWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = DElderDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.curseLeft > 0 { self.curseLeft -= 1.0 / 60.0 }
            let bob = sin(self.phase * 2.0) * 3.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + bob))
            self.drawView?.phase = self.phase
            self.drawView?.hits = self.hits
            self.drawView?.cursed = self.curseLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func registerHit() -> Int {
        if !isDefeated { _ = counter.hit() }
        hits = counter.hits
        drawView?.needsDisplay = true
        return hits
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DElderDrawView: NSView {
    var phase: TimeInterval = 0
    var hits = 0
    var cursed = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 대형 몸통 (회청색 가시)
        ctx.setFillColor(red: 0.45, green: 0.55, blue: 0.55, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 42, y: 8, width: 84, height: 60))
        // 가시 돌기
        ctx.setFillColor(red: 0.35, green: 0.45, blue: 0.45, alpha: 1.0)
        for i in 0..<7 {
            let a = Double(i) / 7.0 * Double.pi * 2.0 + phase * 0.6
            let sx = cx + CGFloat(cos(a)) * 42
            let sy = 38 + CGFloat(sin(a)) * 30
            ctx.fill(CGRect(x: sx - 3, y: sy - 3, width: 7, height: 7))
        }
        // 대형 눈 흰자 + 동공 (저주 시 보라)
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.90, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 22, y: 24, width: 44, height: 30))
        if cursed {
            ctx.setFillColor(red: 0.55, green: 0.20, blue: 0.80, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        }
        let look = sin(phase * 1.5) * 4.0
        ctx.fillEllipse(in: CGRect(x: cx - 7 + look, y: 32, width: 15, height: 15))
        // 맞은 자국 (4타 중)
        ctx.setFillColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1.0)
        for i in 0..<hits {
            ctx.fill(CGRect(x: 12 + CGFloat(i) * 10, y: 70, width: 7, height: 7))
        }
    }
}

// MARK: - 🐡 가디언: 3초 레이저 사이클

public final class DGuardianWindow: EntityWindow {
    public var position: CGPoint
    private var counter = HitCounter(maxHits: 2)
    public private(set) var hits: Int = 0
    private let onTap: (DGuardianWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: DGuardianDrawView?
    private let panelW: CGFloat = 120
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (DGuardianWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = DGuardianDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        var firedForCycle = -1
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            let cycle = fmod(self.phase, 3.0)
            let cycleIndex = Int(self.phase / 3.0)
            // 발사 순간(2.2~2.5초)에 플레이어가 가까우면 넉백 이모지
            if cycle >= 2.2 && cycle < 2.5 && firedForCycle != cycleIndex {
                firedForCycle = cycleIndex
                let me = RewardCenter.me()
                if me != .zero && abs(me.x - self.position.x) < 140 && abs(me.y - self.position.y) < 120 {
                    RewardCenter.say("💥 지직! 레이저에 맞았다!")
                    SoundAndEffectsManager.shared.play(.alert)
                }
            }
            self.drawView?.cycle = cycle
            self.drawView?.bob = sin(self.phase * 3.0) * 2.0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func registerHit() -> Bool {
        let defeated = counter.hit()
        hits = counter.hits
        return defeated
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DGuardianDrawView: NSView {
    var cycle: TimeInterval = 0
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 조준선 (3초 사이클: 0~2.2 충전, 2.2~2.5 발사)
        if cycle < 2.2 {
            let a = 0.25 + 0.55 * (cycle / 2.2)
            ctx.setStrokeColor(red: 1.0, green: 0.30, blue: 0.20, alpha: a)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 30, y: 30 + bob))
            ctx.addLine(to: CGPoint(x: 110, y: 30 + bob))
            ctx.strokePath()
        } else if cycle < 2.5 {
            ctx.setStrokeColor(red: 1.0, green: 0.90, blue: 0.20, alpha: 1.0)
            ctx.setLineWidth(4.0)
            ctx.move(to: CGPoint(x: 30, y: 30 + bob))
            ctx.addLine(to: CGPoint(x: 110, y: 30 + bob))
            ctx.strokePath()
        }
        // 몸통 (주황 가시복)
        ctx.setFillColor(red: 0.95, green: 0.60, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 16 + bob, width: 34, height: 28))
        ctx.setFillColor(red: 0.85, green: 0.50, blue: 0.15, alpha: 1.0)
        for p in [CGPoint(x: 12, y: 40 + bob), CGPoint(x: 22, y: 46 + bob), CGPoint(x: 32, y: 40 + bob)] {
            ctx.fill(CGRect(x: p.x - 2, y: p.y - 2, width: 5, height: 5))
        }
        // 눈
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 22, y: 27 + bob, width: 7, height: 8))
        // 꼬리 지느러미
        ctx.setFillColor(red: 0.90, green: 0.55, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 26 + bob, width: 8, height: 10))
    }
}

// MARK: - 🐬 돌고래: 플레이어 추종 + 60pt 호위

public final class DDolphinWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isEscorting: Bool = false
    private let onTap: (DDolphinWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: DDolphinDrawView?
    private let panelW: CGFloat = 76
    private let panelH: CGFloat = 44

    public init(startPos: CGPoint, onTap: @escaping (DDolphinWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = DDolphinDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            let me = RewardCenter.me()
            if me != .zero {
                let dx = me.x - self.position.x
                if abs(dx) > 60 {
                    self.position.x += (dx > 0 ? 1 : -1) * 55.0 / 60.0
                }
                let dy = me.y - self.position.y
                if abs(dy) > 60 {
                    self.position.y += (dy > 0 ? 1 : -1) * 30.0 / 60.0
                }
                let dist = hypot(Double(dx), Double(dy))
                let esc = dist <= 60.0
                if esc && !self.isEscorting {
                    RewardCenter.say("🐬💨 돌고래 호위 중! (+30% 기분)")
                }
                self.isEscorting = esc
            }
            let swim = sin(self.phase * 4.0) * 4.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + swim))
            self.drawView?.facingRight = (me.x - self.position.x) >= 0
            self.drawView?.escorting = self.isEscorting
            self.drawView?.swim = swim
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DDolphinDrawView: NSView {
    var facingRight = true
    var escorting = false
    var swim: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통 (파랑)
        ctx.setFillColor(red: 0.35, green: 0.60, blue: 0.90, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 12 + swim, width: 44, height: 20))
        // 부리
        ctx.fillEllipse(in: CGRect(x: 52, y: 17 + swim, width: 12, height: 9))
        // 등지느러미
        ctx.setFillColor(red: 0.28, green: 0.52, blue: 0.80, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 30 + swim, width: 8, height: 9))
        // 꼬리
        ctx.fill(CGRect(x: 2, y: 16 + swim, width: 10, height: 6))
        // 눈
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 48, y: 21 + swim, width: 4, height: 4))
        // 호위 반짝임
        if escorting {
            ctx.setFillColor(red: 1.0, green: 0.90, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 60, y: 34, width: 6, height: 6))
        }
        ctx.restoreGState()
    }
}

// MARK: - 🚢 난파선: 상자 3개 + 지도 조각

public final class DShipwreckWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var opened: Int = 0
    private let onTap: (DShipwreckWindow) -> Void
    private var drawView: DShipwreckDrawView?

    public init(startPos: CGPoint, onTap: @escaping (DShipwreckWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 120, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DShipwreckDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        drawView?.opened = opened
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func openNext() -> (pieces: Int, finished: Bool) {
        if opened < 3 { opened += 1 }
        drawView?.opened = opened
        drawView?.needsDisplay = true
        return (opened, opened >= 3)
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }
}

private final class DShipwreckDrawView: NSView {
    var opened = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 선체 (갈색)
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 8, width: 108, height: 22))
        // 돛대
        ctx.fill(CGRect(x: 58, y: 28, width: 5, height: 34))
        // 상자 3개 (열리면 황금색)
        for i in 0..<3 {
            let x = CGFloat(16 + i * 34)
            if i < opened {
                ctx.setFillColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
            }
            ctx.fill(CGRect(x: x, y: 34, width: 26, height: 18))
            ctx.setFillColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: 41, width: 26, height: 3))
        }
    }
}

// MARK: - 🪸 산호초: 5색 순환 파밍

public final class DCoralWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var collected: [String] = []
    private let onTap: (DCoralWindow) -> Void
    private var drawView: DCoralDrawView?
    private let order = ["빨강", "주황", "노랑", "분홍", "파랑"]

    public init(startPos: CGPoint, onTap: @escaping (DCoralWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 96, height: 64)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DCoralDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        drawView?.count = collected.count
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func collectNext() -> (colorName: String, count: Int, completed: Bool) {
        let next = order[collected.count % order.count]
        collected.append(next)
        let done = collected.count >= 5
        if done { collected.removeAll() }
        drawView?.count = done ? 5 : collected.count
        drawView?.needsDisplay = true
        return (next, done ? 5 : collected.count, done)
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }
}

private final class DCoralDrawView: NSView {
    var count = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cols: [(CGFloat, CGFloat, CGFloat)] = [
            (0.95, 0.25, 0.25), (1.0, 0.60, 0.20), (1.0, 0.85, 0.25), (1.0, 0.45, 0.70), (0.30, 0.55, 1.0),
        ]
        // 바닥 모래
        ctx.setFillColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 2, width: 88, height: 8))
        for i in 0..<5 {
            let x = CGFloat(8 + i * 17)
            let h: CGFloat = (i < count) ? 34 : 20
            let c = cols[i]
            ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: (i < count) ? 1.0 : 0.45)
            ctx.fillEllipse(in: CGRect(x: x, y: 10, width: 14, height: h))
            // 가지
            ctx.fill(CGRect(x: x + 5, y: 10 + h - 6, width: 4, height: 10))
        }
    }
}

// MARK: - 🌿 켈프: 5초/단계 5단계 고속 성장

public final class DKelpWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var stage: Int = 0
    private let onTap: (DKelpWindow) -> Void
    private var tick: Timer?
    private var growthCooldown = Cooldown()
    private var drawView: DKelpDrawView?
    private let maxStage = 5

    public init(startPos: CGPoint, onTap: @escaping (DKelpWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 64, height: 96)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DKelpDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        growthCooldown.trigger(5.0)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if self.stage < self.maxStage {
                self.growthCooldown.tick(1.0)
                if self.growthCooldown.ready {
                    self.growthCooldown.trigger(5.0)
                    self.stage += 1
                    self.drawView?.stage = self.stage
                    self.drawView?.needsDisplay = true
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
        }
        if let t = tick { RunLoop.main.add(t, forMode: .common) }
    }

    public func tryHarvest() -> Bool {
        guard stage >= maxStage else { return false }
        stage = 0
        growthCooldown.trigger(5.0)
        drawView?.stage = stage
        drawView?.needsDisplay = true
        return true
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DKelpDrawView: NSView {
    var stage = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 모래
        ctx.setFillColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 2, width: 56, height: 8))
        // 줄기 (단계별 높이)
        let h = CGFloat(stage) * 15.0
        ctx.setFillColor(red: 0.20, green: 0.55, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: 29, y: 10, width: 6, height: max(6, h)))
        // 잎
        ctx.setFillColor(red: 0.28, green: 0.65, blue: 0.30, alpha: 1.0)
        for i in 0..<stage {
            let y = 14 + CGFloat(i) * 15.0
            ctx.fillEllipse(in: CGRect(x: 20, y: y, width: 12, height: 7))
            ctx.fillEllipse(in: CGRect(x: 32, y: y + 5, width: 12, height: 7))
        }
    }
}

// MARK: - 🏮 바다 랜턴: 밤 자동 점등 장식

public final class DSeaLanternWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isLit: Bool = false
    private let onTap: (DSeaLanternWindow) -> Void
    private var tick: Timer?
    private var drawView: DSeaLanternDrawView?

    public init(startPos: CGPoint, onTap: @escaping (DSeaLanternWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 56, height: 64)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DSeaLanternDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        refresh()
        tick = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let t = tick { RunLoop.main.add(t, forMode: .common) }
    }

    private func refresh() {
        let h = Calendar.current.component(.hour, from: Date())
        let lit = (h >= 18 || h < 6)
        if lit != isLit {
            isLit = lit
            drawView?.isLit = lit
            drawView?.needsDisplay = true
            if lit { SoundAndEffectsManager.shared.play(.chime) }
        }
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DSeaLanternDrawView: NSView {
    var isLit = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 매달림 줄
        ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 54, width: 3, height: 8))
        // 랜턴 틀 (어두운 프리즈머린)
        ctx.setFillColor(red: 0.20, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 8, width: 32, height: 46))
        // 발광 코어 (밤에만 밝게)
        if isLit {
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 16, y: 18, width: 24, height: 26))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 22, y: 26, width: 12, height: 12))
        } else {
            ctx.setFillColor(red: 0.65, green: 0.72, blue: 0.70, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 16, y: 18, width: 24, height: 26))
        }
    }
}

// MARK: - 🐚 조개: 30% 진주

public final class DClamWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (DClamWindow) -> Void
    private var drawView: DClamDrawView?

    public init(startPos: CGPoint, onTap: @escaping (DClamWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 64, height: 48)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DClamDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.splash)
    }

    public func setOpened(pearl: Bool) {
        drawView?.showPearl = pearl
        drawView?.openedTick += 1
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }
}

private final class DClamDrawView: NSView {
    var showPearl = false
    var openedTick = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let open = openedTick > 0
        // 아래 껍데기
        ctx.setFillColor(red: 0.75, green: 0.60, blue: 0.70, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 6, width: 48, height: open ? 18 : 26))
        // 위 껍데기 (열리면 위로)
        ctx.setFillColor(red: 0.82, green: 0.68, blue: 0.78, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: open ? 26 : 16, width: 48, height: 18))
        // 진주 / 모래
        if open {
            if showPearl {
                ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                ctx.fillEllipse(in: CGRect(x: 27, y: 20, width: 10, height: 10))
            } else {
                ctx.setFillColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1.0)
                ctx.fillEllipse(in: CGRect(x: 27, y: 18, width: 10, height: 7))
            }
        }
    }
}

// MARK: - 🤿 심해 상자 (호흡 버프 60초 동안 수확)

public final class DDiveChestWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: () -> Void
    private var done = false
    private var drawView: DDiveChestDrawView?

    public init(startPos: CGPoint, onTap: @escaping () -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 72, height: 56)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DDiveChestDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.splash)
    }

    @discardableResult
    public func harvest() -> Bool {
        guard !done else { return false }
        done = true
        return true
    }

    public override func mouseDown(with event: NSEvent) { onTap() }
}

private final class DDiveChestDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 물방울 배경
        ctx.setFillColor(red: 0.20, green: 0.45, blue: 0.80, alpha: 0.35)
        ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 64, height: 48))
        // 상자
        ctx.setFillColor(red: 0.40, green: 0.28, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 10, width: 40, height: 26))
        ctx.setFillColor(red: 0.55, green: 0.40, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 26, width: 40, height: 10))
        // 자물쇠
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 33, y: 22, width: 6, height: 8))
        // 산소 방울 3개
        ctx.setFillColor(red: 0.70, green: 0.90, blue: 1.0, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: 12, y: 40, width: 6, height: 6))
        ctx.fillEllipse(in: CGRect(x: 54, y: 42, width: 5, height: 5))
        ctx.fillEllipse(in: CGRect(x: 48, y: 34, width: 4, height: 4))
    }
}

// MARK: - 🎣 낚시 대회장 (5분 타이머 + 클릭 낚시)

public final class DFishingContestWindow: EntityWindow {
    public var position: CGPoint
    public var timeLeft: TimeInterval = 300
    public var lastCatch: CGFloat = 0
    private let onTap: (DFishingContestWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: DFishingContestDrawView?

    public init(startPos: CGPoint, onTap: @escaping (DFishingContestWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        let size = NSSize(width: 96, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = DFishingContestDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.phase = self.phase
            self.drawView?.lastCatch = self.lastCatch
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) { onTap(self) }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class DFishingContestDrawView: NSView {
    var phase: TimeInterval = 0
    var lastCatch: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 물결
        ctx.setFillColor(red: 0.25, green: 0.50, blue: 0.90, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: 88, height: 18))
        ctx.setFillColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        let wob = sin(phase * 3.0) * 2.0
        ctx.fillEllipse(in: CGRect(x: 14 + wob, y: 12, width: 20, height: 6))
        ctx.fillEllipse(in: CGRect(x: 58 - wob, y: 12, width: 20, height: 6))
        // 찌
        let bobY = 22 + sin(phase * 2.0) * 2.0
        ctx.setFillColor(red: 1.0, green: 0.25, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 45, y: bobY, width: 7, height: 9))
        // 낚싯줄
        ctx.setStrokeColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 0.8)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: 80, y: 62))
        ctx.addLine(to: CGPoint(x: 48, y: bobY + 8))
        ctx.strokePath()
        // 어부 모자
        ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.40, alpha: 1.0)
        ctx.fill(CGRect(x: 72, y: 52, width: 18, height: 6))
        // 최근 어획 크기 표시 막대
        if lastCatch > 0 {
            let frac = min(1.0, lastCatch / 150.0)
            ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: 8, y: 64, width: 80 * frac, height: 5))
        }
    }
}
