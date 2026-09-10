import AppKit
import CoreGraphics
import Foundation

// I분야 구조물 10종: 저택·소환사·변명자·불길한병·전초기지·고대도시·트라이얼·해저사원·엔드배·영웅 + StructuresIManager.
// StructuresIManager.shared.entries()로 메뉴 연결한다.

public final class StructuresIManager {
    public static let shared = StructuresIManager()

    private var mansion: IMansionWindow?
    private var evoker: IEvokerWindow?
    private var vindicator: IVindicatorWindow?
    private var outpost: IOutpostWindow?
    private var city: IAncientCityWindow?
    private var chamber: ITrialChamberWindow?
    private var temple: IOceanTempleWindow?
    private var ship: IEndShipWindow?
    private var hero: IHeroWindow?
    private var bottleCount = 0
    private var bottleBuffUntil: Date?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🏯 삼림 저택" }, { [weak self] in self?.toggleMansion() }),
            ExtraMenuEntry({ "🧙 소환사" }, { [weak self] in self?.toggleEvoker() }),
            ExtraMenuEntry({ "🪓 변명자" }, { [weak self] in self?.toggleVindicator() }),
            ExtraMenuEntry({ [weak self] in self?.bottleTitle() ?? "🏳️ 불길한 병" }, { [weak self] in self?.tapBottle() }),
            ExtraMenuEntry({ "🏕️ 전초기지" }, { [weak self] in self?.toggleOutpost() }),
            ExtraMenuEntry({ "🏛️ 고대 도시" }, { [weak self] in self?.toggleCity() }),
            ExtraMenuEntry({ "🧪 트라이얼 챔버" }, { [weak self] in self?.toggleChamber() }),
            ExtraMenuEntry({ "🌊 해저 사원" }, { [weak self] in self?.toggleTemple() }),
            ExtraMenuEntry({ "🐲 엔드 배" }, { [weak self] in self?.toggleShip() }),
            ExtraMenuEntry({ "🎖️ 습격 영웅" }, { [weak self] in self?.toggleHero() }),
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

    // MARK: - 저택: 입구 + 방 4개 순차 탐험 + 보스방 해금

    public func toggleMansion() {
        if let w = mansion, w.isVisible {
            w.close(); mansion = nil; return
        }
        mansion = nil
        let w = IMansionWindow(startPos: spawnPos(dx: -80)) { [weak self] tapped in
            self?.handleMansionTap(tapped)
        }
        mansion = w
        w.start()
    }

    private func handleMansionTap(_ w: IMansionWindow) {
        if w.advance() {
            SoundAndEffectsManager.shared.play(.chime)
            if w.stage == IMansionWindow.bossStage {
                RewardCenter.grant(xp: 5, "🏯 보스방 해금!")
            } else {
                RewardCenter.say("🏯 \(w.stageName())")
            }
        } else {
            RewardCenter.say("🏯 이미 정복한 저택!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 소환사: 벡스 3마리(클릭 1타) + 본체 3타 + 토템 확정 +8XP

    public func toggleEvoker() {
        if let w = evoker, w.isVisible {
            w.close(); evoker = nil; return
        }
        evoker = nil
        let w = IEvokerWindow(startPos: spawnPos(dx: 80)) { [weak self] tapped in
            self?.handleEvokerTap(tapped)
        }
        evoker = w
        w.start()
    }

    private func handleEvokerTap(_ w: IEvokerWindow) {
        if w.isVexPhase {
            RewardCenter.say("🧙 벡스를 먼저 처치!")
            SoundAndEffectsManager.shared.play(.alert)
            return
        }
        if w.hitBody() {
            SoundAndEffectsManager.shared.play(.pop)
            if w.isDefeated {
                RewardCenter.grant(xp: 8, "🧙 불사의 토템 확정!")
                SoundAndEffectsManager.shared.play(.chime)
                w.close(); evoker = nil
            } else {
                RewardCenter.say("🧙 \(3 - w.bodyHits)대 남음!")
            }
        }
    }

    // MARK: - 변명자: 도끼 돌진 + 클릭 2타 + "각하!" +4XP

    public func toggleVindicator() {
        if let w = vindicator, w.isVisible {
            w.close(); vindicator = nil; return
        }
        vindicator = nil
        let w = IVindicatorWindow(startPos: spawnPos(dx: 120)) { [weak self] tapped in
            self?.handleVindicatorTap(tapped)
        }
        vindicator = w
        w.start()
    }

    private func handleVindicatorTap(_ w: IVindicatorWindow) {
        if w.hit() {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🪓 각하!")
        } else {
            RewardCenter.grant(xp: 4, "🪓 각하! 변명자 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); vindicator = nil
        }
    }

    // MARK: - 불길한 병: 대장 접근 불가 → 깃발 획득 의식(클릭 3회) + 불길한 예감 10분

    private func bottleTitle() -> String {
        if let until = bottleBuffUntil, until > Date() {
            let left = Int(until.timeIntervalSince(Date()))
            return "🏳️ 불길한 병 (\(left / 60):\(String(format: "%02d", left % 60)))"
        }
        return "🏳️ 불길한 병"
    }

    public func tapBottle() {
        bottleCount += 1
        SoundAndEffectsManager.shared.play(.pop)
        if bottleCount >= 3 {
            bottleCount = 0
            bottleBuffUntil = Date().addingTimeInterval(600)
            RewardCenter.grant(xp: 0, "🏳️ 불길한 예감 10분!")
            SoundAndEffectsManager.shared.play(.alert)
        } else {
            RewardCenter.say("🏳️ 깃발 의식 \(bottleCount)/3")
        }
    }

    // MARK: - 전초기지: 정찰탑 + 상자 2개 + 염소뿔 +3XP

    public func toggleOutpost() {
        if let w = outpost, w.isVisible {
            w.close(); outpost = nil; return
        }
        outpost = nil
        let w = IOutpostWindow(startPos: spawnPos(dx: -120)) { [weak self] tapped in
            self?.handleOutpostTap(tapped)
        }
        outpost = w
        w.start()
    }

    private func handleOutpostTap(_ w: IOutpostWindow) {
        if w.lootChest() {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🏕️ 상자 \(w.lootedChests)/2")
            if w.lootedChests >= 2 {
                RewardCenter.grant(xp: 3, "🏕️ 염소뿔 획득!")
                SoundAndEffectsManager.shared.play(.chime)
            }
        } else {
            RewardCenter.say("🏕️ 이미 털린 전초기지!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 고대 도시: 스컬크 진동 + 긴장 게이지 + 반향 조각 +5XP

    public func toggleCity() {
        if let w = city, w.isVisible {
            w.close(); city = nil; return
        }
        city = nil
        let w = IAncientCityWindow(startPos: spawnPos(dx: 40)) { [weak self] tapped in
            self?.handleCityTap(tapped)
        }
        city = w
        w.start()
    }

    private func handleCityTap(_ w: IAncientCityWindow) {
        w.tremble()
        SoundAndEffectsManager.shared.play(.alert)
        if w.tension >= 100 {
            RewardCenter.grant(xp: 5, "🏛️ 반향 조각!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); city = nil
        } else {
            RewardCenter.say("🏛️ 긴장 \(Int(w.tension))%...")
        }
    }

    // MARK: - 트라이얼 챔버: 웨이브 3(1→2→3) + 열쇠 + 메이스 +8XP

    public func toggleChamber() {
        if let w = chamber, w.isVisible {
            w.close(); chamber = nil; return
        }
        chamber = nil
        let w = ITrialChamberWindow(startPos: spawnPos(dx: -40)) { [weak self] tapped in
            self?.handleChamberTap(tapped)
        }
        chamber = w
        w.start()
    }

    private func handleChamberTap(_ w: ITrialChamberWindow) {
        if w.hitOne() {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🧪 웨이브 \(w.wave)/3 · \(w.leftInWave) 남음")
        } else {
            RewardCenter.grant(xp: 8, "🧪 🔑 메이스 획득!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); chamber = nil
        }
    }

    // MARK: - 해저 사원: 물 오버레이 + 물빼기 5초 + 황금 블록 4개 +6XP

    public func toggleTemple() {
        if let w = temple, w.isVisible {
            w.close(); temple = nil; return
        }
        temple = nil
        let w = IOceanTempleWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleTempleTap(tapped)
        }
        temple = w
        w.start()
    }

    private func handleTempleTap(_ w: IOceanTempleWindow) {
        if !w.isDrained {
            w.startDrain()
            RewardCenter.say("🌊 물빼기 중... 5초!")
            SoundAndEffectsManager.shared.play(.splash)
            return
        }
        if w.mineGold() {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🌊 황금 \(w.minedGold)/4")
            if w.minedGold >= 4 {
                RewardCenter.grant(xp: 6, "🌊 해저 사원 정복!")
                SoundAndEffectsManager.shared.play(.chime)
                w.close(); temple = nil
            }
        }
    }

    // MARK: - 엔드 배(I원정): 항해 30초 + 엘리트라 파편 3개 + 완성 +6XP

    public func toggleShip() {
        if let w = ship, w.isVisible {
            w.close(); ship = nil; return
        }
        ship = nil
        let w = IEndShipWindow(startPos: spawnPos(dx: -160)) { [weak self] tapped in
            self?.handleShipTap(tapped)
        }
        ship = w
        w.start()
    }

    private func handleShipTap(_ w: IEndShipWindow) {
        if w.collectFragment() {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🐲 파편 \(w.fragments)/3")
        }
        if w.isComplete {
            RewardCenter.grant(xp: 6, "🐲 엘리트라 완성!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); ship = nil
        } else if !w.voyageDone {
            RewardCenter.say("🐲 항해 중 \(Int(w.progress * 100))%...")
        }
    }

    // MARK: - 습격 영웅: 주민 퍼레이드 + 할인 기분 + 폭죽 +4XP

    public func toggleHero() {
        if let w = hero, w.isVisible {
            w.close(); hero = nil; return
        }
        hero = nil
        let w = IHeroWindow(startPos: spawnPos(dx: 160)) { [weak self] tapped in
            self?.handleHeroTap(tapped)
        }
        hero = w
        w.start()
    }

    private func handleHeroTap(_ w: IHeroWindow) {
        w.fireworks()
        SoundAndEffectsManager.shared.play(.chime)
        if w.cheers >= 2 {
            RewardCenter.grant(xp: 4, "🎖️ 🎟️ 할인 기분 + 폭죽!")
            w.close(); hero = nil
        } else {
            RewardCenter.say("🎖️ 주민 퍼레이드!")
        }
    }
}

// MARK: - I저택: 입구 + 방 4개 + 보스방 (클릭당 1단계)

public final class IMansionWindow: NSPanel {
    public static let bossStage = 5
    public private(set) var stage = 0
    private let onTap: (IMansionWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: IMansionDrawView?
    private let panelW: CGFloat = 148
    private let panelH: CGFloat = 96

    public init(startPos: CGPoint, onTap: @escaping (IMansionWindow) -> Void) {
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
        let view = IMansionDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.stage = self.stage
            self.drawView?.flicker = sin(self.phase * 4.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func stageName() -> String {
        switch stage {
        case 0: return "입구"
        case 1...4: return "방 \(stage)/4"
        default: return "보스방!"
        }
    }

    @discardableResult
    public func advance() -> Bool {
        guard stage < IMansionWindow.bossStage else { return false }
        stage += 1
        drawView?.stage = stage
        drawView?.needsDisplay = true
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

private final class IMansionDrawView: NSView {
    var stage = 0
    var flicker: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.45, green: 0.36, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 10, width: 132, height: 70))
        ctx.setFillColor(red: 0.30, green: 0.22, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 70, width: 132, height: 10))
        for i in 0..<4 {
            let lit = i < min(stage, 4)
            if lit {
                ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.16, green: 0.14, blue: 0.18, alpha: 1.0)
            }
            ctx.fill(CGRect(x: 18 + CGFloat(i) * 30, y: 34, width: 22, height: 26))
        }
        if stage >= IMansionWindow.bossStage {
            let glow = 0.6 + 0.4 * flicker
            ctx.setFillColor(red: 1.0, green: CGFloat(0.3 + 0.3 * Double(glow)), blue: 0.2, alpha: 1.0)
            ctx.fill(CGRect(x: 62, y: 2, width: 24, height: 22))
        } else {
            ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 1.0)
            ctx.fill(CGRect(x: 62, y: 2, width: 24, height: 22))
        }
    }
}

// MARK: - I소환사 + I벡스 3마리

public final class IIllagerVexWindow: NSPanel {
    private let onTap: (IIllagerVexWindow) -> Void
    private var hp = 1

    public init(startPos: CGPoint, onTap: @escaping (IIllagerVexWindow) -> Void) {
        self.onTap = onTap
        let size = NSSize(width: 30, height: 30)
        super.init(
            contentRect: NSRect(x: startPos.x - 15, y: startPos.y, width: size.width, height: size.height),
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
        contentView = IIllagerVexDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public override func mouseDown(with event: NSEvent) {
        hp -= 1
        if hp <= 0 {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("👻 벡스 처치!")
            close()
        }
        onTap(self)
    }
}

private final class IIllagerVexDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 0.95)
        ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 14, height: 16))
        ctx.setFillColor(red: 0.95, green: 0.20, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 11, y: 17, width: 3, height: 4))
        ctx.fillEllipse(in: CGRect(x: 16, y: 17, width: 3, height: 4))
        ctx.setFillColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: 0, y: 12, width: 9, height: 6))
        ctx.fillEllipse(in: CGRect(x: 21, y: 12, width: 9, height: 6))
    }
}

public final class IEvokerWindow: NSPanel {
    public private(set) var bodyHits = 0
    public private(set) var vexAlive = 3
    public var isVexPhase: Bool { vexAlive > 0 }
    public var isDefeated: Bool { bodyHits >= 3 }
    private let onTap: (IEvokerWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var vexes: [IIllagerVexWindow] = []
    private var drawView: IEvokerDrawView?
    private var basePos: CGPoint
    private let panelW: CGFloat = 56
    private let panelH: CGFloat = 76

    public init(startPos: CGPoint, onTap: @escaping (IEvokerWindow) -> Void) {
        self.basePos = startPos
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
        let view = IEvokerDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        for i in 0..<3 {
            let pos = CGPoint(x: basePos.x + CGFloat(i - 1) * 44, y: basePos.y + 84)
            let v = IIllagerVexWindow(startPos: pos) { [weak self] _ in
                guard let self = self else { return }
                self.vexAlive = max(0, self.vexAlive - 1)
                self.drawView?.vexLeft = self.vexAlive
                self.drawView?.needsDisplay = true
                if self.vexAlive == 0 {
                    RewardCenter.say("🧙 본체 등장!")
                    SoundAndEffectsManager.shared.play(.alert)
                }
            }
            vexes.append(v)
            v.orderFrontRegardless()
        }
        drawView?.vexLeft = vexAlive
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hitBody() -> Bool {
        guard !isVexPhase, !isDefeated else { return false }
        bodyHits += 1
        drawView?.hits = bodyHits
        drawView?.needsDisplay = true
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        for v in vexes { v.close() }
        vexes.removeAll()
        super.close()
    }
}

private final class IEvokerDrawView: NSView {
    var hits = 0
    var vexLeft = 3
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let bob = sin(phase * 3.0) * 2
        ctx.setFillColor(red: 0.35, green: 0.30, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 8 + bob, width: 24, height: 36))
        ctx.setFillColor(red: 0.85, green: 0.72, blue: 0.62, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 17, y: 44 + bob, width: 22, height: 20))
        ctx.setFillColor(red: 0.15, green: 0.35, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 21, y: 51 + bob, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: 30, y: 51 + bob, width: 5, height: 6))
        ctx.setFillColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 20 + bob - CGFloat(hits) * 2, width: 6, height: 18))
        for i in 0..<3 {
            if i < vexLeft {
                ctx.setFillColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 0.4)
            }
            ctx.fillEllipse(in: CGRect(x: 12 + CGFloat(i) * 12, y: 2, width: 8, height: 8))
        }
    }
}

// MARK: - I변명자: 도끼 돌진 + 2타

public final class IVindicatorWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (IVindicatorWindow) -> Void
    private var hp = 2
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var drawView: IVindicatorDrawView?
    private let panelW: CGFloat = 52
    private let panelH: CGFloat = 70

    public init(startPos: CGPoint, onTap: @escaping (IVindicatorWindow) -> Void) {
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
        let view = IVindicatorDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            let me = RewardCenter.me()
            if me != .zero {
                let d = me.x - self.position.x
                if abs(d) > 10 { self.dir = d > 0 ? 1 : -1 }
            }
            self.position.x += self.dir * 150.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.step = sin(self.phase * 12.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        hp -= 1
        return hp > 0
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

private final class IVindicatorDrawView: NSView {
    var facingRight = true
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        ctx.setFillColor(red: 0.40, green: 0.36, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 10, width: 20, height: 32))
        ctx.setFillColor(red: 0.85, green: 0.72, blue: 0.62, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 17, y: 42, width: 18, height: 18))
        let swing = step * 5
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 36, y: 24 + swing, width: 4, height: 20))
        ctx.setFillColor(red: 0.70, green: 0.70, blue: 0.72, alpha: 1.0)
        ctx.fill(CGRect(x: 32, y: 40 + swing, width: 12, height: 8))
        ctx.setFillColor(red: 0.30, green: 0.28, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 0, width: 7, height: 10 + swing))
        ctx.fill(CGRect(x: 28, y: 0, width: 7, height: 10 - swing))
        ctx.restoreGState()
    }
}

// MARK: - I전초기지: 정찰탑 + 상자 2개

public final class IOutpostWindow: NSPanel {
    public private(set) var lootedChests = 0
    private let onTap: (IOutpostWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: IOutpostDrawView?
    private let panelW: CGFloat = 132
    private let panelH: CGFloat = 110

    public init(startPos: CGPoint, onTap: @escaping (IOutpostWindow) -> Void) {
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
        let view = IOutpostDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.looted = self.lootedChests
            self.drawView?.flagWave = sin(self.phase * 5.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func lootChest() -> Bool {
        guard lootedChests < 2 else { return false }
        lootedChests += 1
        drawView?.looted = lootedChests
        drawView?.needsDisplay = true
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

private final class IOutpostDrawView: NSView {
    var looted = 0
    var flagWave: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.50, green: 0.40, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 52, y: 18, width: 28, height: 70))
        ctx.setFillColor(red: 0.42, green: 0.33, blue: 0.22, alpha: 1.0)
        for y in [30, 48, 66] as [CGFloat] {
            ctx.fill(CGRect(x: 48, y: y, width: 36, height: 5))
        }
        ctx.setFillColor(red: 0.60, green: 0.48, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 46, y: 86, width: 40, height: 16))
        ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 63, y: 102, width: 3, height: 8))
        ctx.setFillColor(red: 0.70, green: 0.75, blue: 0.72, alpha: 1.0)
        ctx.fill(CGRect(x: 66, y: 100 + flagWave, width: 16, height: 9))
        for i in 0..<2 {
            let opened = i < looted
            if opened {
                ctx.setFillColor(red: 0.35, green: 0.28, blue: 0.20, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.65, green: 0.48, blue: 0.26, alpha: 1.0)
            }
            ctx.fill(CGRect(x: 6 + CGFloat(i) * 36, y: 0, width: 30, height: 18))
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
            ctx.fill(CGRect(x: 17 + CGFloat(i) * 36, y: 7, width: 8, height: 5))
        }
    }
}

// MARK: - I고대도시: 스컬크 진동 + 긴장 게이지

public final class IAncientCityWindow: NSPanel {
    public private(set) var tension: CGFloat = 0
    private let onTap: (IAncientCityWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var shake: CGFloat = 0
    private var drawView: IAncientCityDrawView?
    private let panelW: CGFloat = 150
    private let panelH: CGFloat = 70

    public init(startPos: CGPoint, onTap: @escaping (IAncientCityWindow) -> Void) {
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
        let view = IAncientCityDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
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
            self.drawView?.tension = self.tension
            self.drawView?.shake = self.shake > 0 ? sin(self.phase * 60.0) * 3 : 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func tremble() {
        tension = min(100, tension + 34)
        shake = 0.4
        drawView?.tension = tension
        drawView?.needsDisplay = true
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

private final class IAncientCityDrawView: NSView {
    var tension: CGFloat = 0
    var shake: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: shake, y: 0)
        ctx.setFillColor(red: 0.12, green: 0.16, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 0, width: 142, height: 40))
        ctx.setFillColor(red: 0.15, green: 0.55, blue: 0.60, alpha: 1.0)
        for x in [14, 44, 74, 104] as [CGFloat] {
            ctx.fillEllipse(in: CGRect(x: x, y: 8, width: 16, height: 10))
        }
        ctx.setFillColor(red: 0.30, green: 0.32, blue: 0.36, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 40, width: 142, height: 8))
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 48, width: 142, height: 6))
        let ratio = tension / 100.0
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 56, width: 142, height: 8))
        ctx.setFillColor(red: 0.55 + 0.45 * ratio, green: 0.75 - 0.45 * ratio, blue: 0.95 - 0.5 * ratio, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 56, width: 142 * ratio, height: 8))
        ctx.restoreGState()
    }
}

// MARK: - I트라이얼챔버: 웨이브 3 (1→2→3)

public final class ITrialChamberWindow: NSPanel {
    public private(set) var wave = 1
    public private(set) var leftInWave = 1
    private let onTap: (ITrialChamberWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: ITrialChamberDrawView?
    private let panelW: CGFloat = 120
    private let panelH: CGFloat = 84

    public init(startPos: CGPoint, onTap: @escaping (ITrialChamberWindow) -> Void) {
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
        let view = ITrialChamberDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.wave = self.wave
            self.drawView?.left = self.leftInWave
            self.drawView?.pulse = sin(self.phase * 6.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    // true = 웨이브 진행 중, false = 전 웨이브 클리어(보상 지급 시점)
    public func hitOne() -> Bool {
        leftInWave -= 1
        if leftInWave > 0 { return true }
        if wave >= 3 { return false }
        wave += 1
        leftInWave = wave
        drawView?.wave = wave
        drawView?.left = leftInWave
        drawView?.needsDisplay = true
        RewardCenter.say("🧪 🔑 보상고 열림!")
        SoundAndEffectsManager.shared.play(.chime)
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

private final class ITrialChamberDrawView: NSView {
    var wave = 1
    var left = 1
    var pulse: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 6, width: 108, height: 60))
        ctx.setFillColor(red: 0.42, green: 0.55, blue: 0.58, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 56, width: 108, height: 10))
        for i in 0..<3 {
            let y = 14 + CGFloat(i) * 15
            ctx.setFillColor(red: 0.30, green: 0.60, blue: 0.65, alpha: 1.0)
            ctx.fill(CGRect(x: 14, y: y, width: 92, height: 3))
        }
        for i in 0..<left {
            let bob = pulse * 2
            ctx.setFillColor(red: 0.95, green: 0.35, blue: 0.25, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 30 + CGFloat(i) * 24, y: 26 + bob, width: 16, height: 20))
        }
        ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 88, y: 66, width: 20, height: 16))
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 95, y: 72, width: 6, height: 6))
    }
}

// MARK: - I해저사원: 물빼기 5초 + 황금 4개

public final class IOceanTempleWindow: NSPanel {
    public private(set) var isDrained = false
    public private(set) var minedGold = 0
    private let onTap: (IOceanTempleWindow) -> Void
    private var tick: Timer?
    private var drainTimer: Timer?
    private var phase: TimeInterval = 0
    private var drainLeft: TimeInterval = 0
    private var drawView: IOceanTempleDrawView?
    private let panelW: CGFloat = 140
    private let panelH: CGFloat = 90

    public init(startPos: CGPoint, onTap: @escaping (IOceanTempleWindow) -> Void) {
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
        let view = IOceanTempleDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.drained = self.isDrained
            self.drawView?.mined = self.minedGold
            self.drawView?.wave = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func startDrain() {
        guard !isDrained, drainTimer == nil else { return }
        drainLeft = 5.0
        drainTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.drainLeft -= 0.1
            if self.drainLeft <= 0 {
                t.invalidate()
                self.drainTimer = nil
                self.isDrained = true
                self.drawView?.drained = true
                self.drawView?.needsDisplay = true
                RewardCenter.say("🧽 물빼기 완료! 황금 4개!")
                SoundAndEffectsManager.shared.play(.chime)
            }
        }
        RunLoop.main.add(drainTimer!, forMode: .common)
    }

    public func mineGold() -> Bool {
        guard isDrained, minedGold < 4 else { return false }
        minedGold += 1
        drawView?.mined = minedGold
        drawView?.needsDisplay = true
        return true
    }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        drainTimer?.invalidate()
        drainTimer = nil
        super.close()
    }
}

private final class IOceanTempleDrawView: NSView {
    var drained = false
    var mined = 0
    var wave: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.45, green: 0.55, blue: 0.52, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 6, width: 120, height: 62))
        ctx.setFillColor(red: 0.30, green: 0.42, blue: 0.40, alpha: 1.0)
        ctx.fill(CGRect(x: 55, y: 24, width: 30, height: 26))
        if !drained {
            ctx.setFillColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 0.55)
            ctx.fill(CGRect(x: 10, y: 6 + wave * 2, width: 120, height: 62))
        }
        for i in 0..<4 {
            let done = i < mined
            if done {
                ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1.0)
            }
            ctx.fill(CGRect(x: 20 + CGFloat(i) * 28, y: 68, width: 22, height: 16))
        }
    }
}

// MARK: - I엔드배(I원정): 항해 30초 + 파편 3개

public final class IEndShipWindow: NSPanel {
    public private(set) var fragments = 0
    public private(set) var progress: CGFloat = 0
    public var voyageDone: Bool { progress >= 1.0 }
    public var isComplete: Bool { voyageDone && fragments >= 3 }
    private let onTap: (IEndShipWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var drawView: IEndShipDrawView?
    private let panelW: CGFloat = 150
    private let panelH: CGFloat = 80

    public init(startPos: CGPoint, onTap: @escaping (IEndShipWindow) -> Void) {
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
        let view = IEndShipDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.elapsed += 1.0 / 60.0
            self.progress = min(1.0, CGFloat(self.elapsed / 30.0))
            self.drawView?.progress = self.progress
            self.drawView?.fragments = self.fragments
            self.drawView?.bob = sin(self.phase * 2.0) * 3
            self.drawView?.needsDisplay = true
            if self.isComplete {
                t.invalidate()
                self.tick = nil
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func collectFragment() -> Bool {
        guard fragments < 3 else { return false }
        fragments += 1
        drawView?.fragments = fragments
        drawView?.needsDisplay = true
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

private final class IEndShipDrawView: NSView {
    var progress: CGFloat = 0
    var fragments = 0
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.85, green: 0.82, blue: 0.70, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 20, y: 10 + bob, width: 110, height: 30))
        ctx.setFillColor(red: 0.70, green: 0.66, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 70, y: 36 + bob, width: 8, height: 26))
        ctx.setFillColor(red: 0.90, green: 0.88, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 78, y: 40 + bob, width: 34, height: 20))
        for i in 0..<3 {
            if i < fragments {
                ctx.setFillColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.33, alpha: 0.5)
            }
            ctx.fillEllipse(in: CGRect(x: 26 + CGFloat(i) * 18, y: 62, width: 14, height: 12))
        }
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 2, width: 138, height: 5))
        ctx.setFillColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 2, width: 138 * progress, height: 5))
    }
}

// MARK: - I습격영웅: 주민 퍼레이드 + 폭죽

public final class IHeroWindow: NSPanel {
    public private(set) var cheers = 0
    private let onTap: (IHeroWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var sparkLeft: TimeInterval = 0
    private var drawView: IHeroDrawView?
    private let panelW: CGFloat = 150
    private let panelH: CGFloat = 70

    public init(startPos: CGPoint, onTap: @escaping (IHeroWindow) -> Void) {
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
        let view = IHeroDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.heart)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.sparkLeft > 0 { self.sparkLeft -= 1.0 / 60.0 }
            self.drawView?.phase = self.phase
            self.drawView?.spark = self.sparkLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func fireworks() {
        cheers += 1
        sparkLeft = 0.8
        drawView?.spark = true
        drawView?.needsDisplay = true
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

private final class IHeroDrawView: NSView {
    var phase: TimeInterval = 0
    var spark = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        for i in 0..<3 {
            let x = 20 + CGFloat(i) * 36
            let jump = abs(sin(phase * 4.0 + Double(i))) * 6
            ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.32, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: 6 + jump, width: 20, height: 28))
            ctx.setFillColor(red: 0.90, green: 0.75, blue: 0.65, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: x + 1, y: 32 + jump, width: 18, height: 16))
            ctx.setFillColor(red: 0.30, green: 0.20, blue: 0.25, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: x + 6, y: 38 + jump, width: 3, height: 3))
            ctx.fillEllipse(in: CGRect(x: x + 12, y: 38 + jump, width: 3, height: 3))
        }
        if spark {
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 60, y: 50, width: 8, height: 8))
            ctx.fillEllipse(in: CGRect(x: 40, y: 56, width: 5, height: 5))
            ctx.fillEllipse(in: CGRect(x: 85, y: 56, width: 5, height: 5))
            ctx.setFillColor(red: 1.0, green: 0.45, blue: 0.55, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 70, y: 58, width: 5, height: 5))
        }
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 118, y: 8, width: 24, height: 16))
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 122, y: 13, width: 16, height: 3))
    }
}
