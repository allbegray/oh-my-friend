import AppKit
import CoreGraphics
import Foundation

// E분야 동물 10종: 늑대갑옷·아르마딜로·고양이선물·열대어·말갑옷·당나귀·노새·스켈레톤마·좀비마·앵무새모방 + AnimalsEManager.
// AppController "🎉 추가 모션" 서브메뉴에서 AnimalsEManager.shared.entries()로 호출한다.
// 상태(인갑·도감·기록)는 모두 메모리 보관(UserDefaults 사용 안 함).

public final class AnimalsEManager {
    public static let shared = AnimalsEManager()

    // 늑대 갑옷: 아르마딜로 클릭 누적 인갑 (6개 상한)
    private var scuteCount: Int = 0
    private var wolfArmorEquipped: Bool = false
    private var wolfStand: EWolfArmorStandWindow?
    // 고양이 선물: 다음 아침(06시) 예약 (메모리 Timer)
    private var giftReserved: Bool = false
    private var giftTimer: Timer?
    private var giftBox: EGiftCatWindow?
    // 열대어 도감 20종 (메모리 Set)
    private var fishCaught: Set<Int> = []
    private var fishBonusGiven: Bool = false
    private var fishTank: ETropicalFishWindow?
    // 말 갑옷 전시 등급
    private var horseArmorTier: String?
    private var horseStand: EHorseArmorWindow?
    // 당나귀 길들이기 + XP 뱅크(15칸)
    private var donkey: EDonkeyWindow?
    private var donkeyTaps: Int = 0
    private var donkeyTamed: Bool = false
    private var donkeyBank: Int = 0
    // 노새 최고 점프 기록 (메모리)
    private var mule: EMuleWindow?
    private var muleBest: CGFloat = 0
    // 스켈레톤마 / 좀비마
    private var skeletonHorse: ESkeletonHorseWindow?
    private var skeletonRiding: Bool = false
    private var zombieHorse: EZombieHorseWindow?
    private var zombieRiding: Bool = false
    // 앵무새 모방 순환 인덱스
    private var mimic: EParrotMimicWindow?
    private var mimicIndex: Int = 0
    // 아르마딜로
    private var armadillo: EArmadilloWindow?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🛡️ 늑대 갑옷" }
                if self.wolfArmorEquipped { return "🛡️ 늑대 갑옷 장착됨" }
                return "🛡️ 늑대 갑옷 (인갑 \(self.scuteCount)/6)"
            }, { [weak self] in self?.runWolfArmor() }),
            ExtraMenuEntry({ "🦔 아르마딜로" }, { [weak self] in self?.toggleArmadillo() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🎁 고양이 선물" }
                return self.giftReserved ? "🎁 고양이 선물 예약됨" : "🎁 고양이 선물"
            }, { [weak self] in self?.runGift() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🐠 열대어" }
                return "🐠 열대어 (\(self.fishCaught.count)/20)"
            }, { [weak self] in self?.toggleFish() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🐴 말 갑옷" }
                if let t = self.horseArmorTier { return "🐴 말 갑옷 \(t) 장착됨" }
                return "🐴 말 갑옷"
            }, { [weak self] in self?.runHorseArmor() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🫏 당나귀" }
                if self.donkeyTamed { return "🫏 당나귀 길들임 (📦 \(self.donkeyBank)/15)" }
                return "🫏 당나귀 (\(self.donkeyTaps)/3)"
            }, { [weak self] in self?.toggleDonkey() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🐎 노새" }
                if self.muleBest > 0 { return "🐎 노새 최고 \(Int(self.muleBest))" }
                return "🐎 노새"
            }, { [weak self] in self?.toggleMule() }),
            ExtraMenuEntry({ "💀 스켈레톤마" }, { [weak self] in self?.toggleSkeletonHorse() }),
            ExtraMenuEntry({ "🧟 좀비마" }, { [weak self] in self?.toggleZombieHorse() }),
            ExtraMenuEntry({ "🦜 앵무새 모방" }, { [weak self] in self?.toggleMimic() }),
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

    // MARK: - 🛡️ 늑대 갑옷: 인갑 6개 모으면 제작 → 펫 방어 + "장착됨"

    private func runWolfArmor() {
        if wolfArmorEquipped {
            toggleWolfStand()
            return
        }
        if scuteCount >= 6 {
            wolfArmorEquipped = true
            RewardCenter.grant(xp: 5, "🛡️ 늑대 갑옷 제작! 펫 방어!")
            SoundAndEffectsManager.shared.play(.chime)
            toggleWolfStand()
        } else {
            RewardCenter.say("🛡️ 인갑 \(scuteCount)/6 — 아르마딜로를 쓰다듬어줘!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    private func toggleWolfStand() {
        if let w = wolfStand, w.isVisible {
            w.close(); wolfStand = nil; return
        }
        wolfStand = nil
        let w = EWolfArmorStandWindow(startPos: spawnPos(dx: 0))
        wolfStand = w
        w.start()
    }

    // MARK: - 🦔 아르마딜로: 사막 배회 + 클릭 시 인갑 +1(6 상한) + 몸말기

    private func toggleArmadillo() {
        if let w = armadillo, w.isVisible {
            w.close(); armadillo = nil; return
        }
        armadillo = nil
        let w = EArmadilloWindow(startPos: spawnPos(dx: -80)) { [weak self] tapped in
            self?.handleArmadilloTap(tapped)
        }
        armadillo = w
        w.start()
    }

    private func handleArmadilloTap(_ w: EArmadilloWindow) {
        w.curlUp()
        if scuteCount < 6 {
            scuteCount += 1
            if scuteCount >= 6 {
                RewardCenter.grant(xp: 2, "🦔 인갑 6개! 늑대 갑옷 제작 가능!")
                SoundAndEffectsManager.shared.play(.chime)
            } else {
                RewardCenter.say("🦔 인갑 +1 (\(scuteCount)/6)")
                SoundAndEffectsManager.shared.play(.pop)
            }
        } else {
            RewardCenter.say("🦔 몸을 둥글게 말았다!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🎁 고양이 선물: 다음 아침(06시) 예약 → 깃털·실·생선 중 랜덤 +2XP

    private func runGift() {
        if let b = giftBox, b.isVisible {
            claimGift(immediate: true)
            return
        }
        giftBox = nil
        let b = EGiftCatWindow(startPos: spawnPos(dx: 80)) { [weak self] in
            self?.claimGift(immediate: true)
        }
        giftBox = b
        b.start()
        reserveGift()
    }

    private func reserveGift() {
        giftTimer?.invalidate()
        giftReserved = true
        let now = Date()
        let cal = Calendar.current
        var comp = cal.dateComponents([.year, .month, .day], from: now)
        comp.hour = 6; comp.minute = 0; comp.second = 0
        var target = cal.date(from: comp) ?? now.addingTimeInterval(60)
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? now.addingTimeInterval(3600)
        }
        let interval = max(1.0, target.timeIntervalSince(now))
        giftTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] t in
            t.invalidate()
            self?.claimGift(immediate: false)
        }
        if let gt = giftTimer { RunLoop.main.add(gt, forMode: .common) }
        RewardCenter.say("🎁 다음 아침(06시)에 선물이 도착해!")
        SoundAndEffectsManager.shared.play(.pop)
    }

    private func claimGift(immediate: Bool) {
        giftTimer?.invalidate()
        giftTimer = nil
        giftReserved = false
        let loot = ["🪶 깃털", "🧵 실", "🐟 생선"]
        let pick = loot.randomElement() ?? "🐟 생선"
        if immediate {
            RewardCenter.grant(xp: 2, "🎁 \(pick)! (미리 열기)")
        } else {
            RewardCenter.grant(xp: 2, "🎁 아침 선물 \(pick)!")
        }
        SoundAndEffectsManager.shared.play(.chime)
        if let b = giftBox {
            b.close(); giftBox = nil
        }
    }

    // MARK: - 🐠 열대어: 빈 양동이 들고 클릭 시 20종 중 랜덤 포획 + 도감

    public static let eFishPatterns: [String] = [
        "🔴 빨강 베타", "🔵 파랑 댐셀", "🟡 노랑 탱", "🟠 오렌지 클라운", "⚪ 흰 몰리",
        "⚫ 검정 테트라", "🟣 보라 구피", "🟤 갈색 메기", "🩷 분홍 엔젤", "🩵 하늘 네온",
        "💚 초록 코리", "❤️‍🔥 불꽃 플라티", "🌊 파도 서전", "☀️ 태양 구라미", "🌙 달빛 고기",
        "⭐ 별무늬 랍", "🔥 용암 디스커스", "❄️ 눈꽃 빙어", "👑 황금 아로와나", "🌈 무지개 레인보우",
    ]

    private func toggleFish() {
        if let w = fishTank, w.isVisible {
            w.close(); fishTank = nil; return
        }
        fishTank = nil
        let w = ETropicalFishWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleFishTap(tapped)
        }
        fishTank = w
        w.start()
    }

    private func handleFishTap(_ w: ETropicalFishWindow) {
        let held = RewardCenter.heldItemName?() ?? ""
        let hasBucket = held.contains("양동이") || held.contains("물통") || held.contains("버킷") || held.lowercased().contains("bucket")
        if !hasBucket {
            RewardCenter.say("🐠 빈 양동이를 들고 클릭해! (물통)")
            SoundAndEffectsManager.shared.play(.splash)
            w.splash()
            return
        }
        let uncaught = Set(0..<Self.eFishPatterns.count).subtracting(fishCaught)
        let idx: Int
        if let pick = uncaught.randomElement() {
            idx = pick
            fishCaught.insert(idx)
        } else {
            idx = Int.random(in: 0..<Self.eFishPatterns.count)
        }
        w.caughtFlash()
        if fishCaught.count >= 20 && !fishBonusGiven {
            fishBonusGiven = true
            RewardCenter.grant(xp: 10, "🐠 도감 완성 20/20! +10XP!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.grant(xp: 1, "🐠 \(Self.eFishPatterns[idx])! (\(fishCaught.count)/20)")
            SoundAndEffectsManager.shared.play(.gulp)
        }
    }

    // MARK: - 🐴 말 갑옷: 철·금·다이아 3지선다 → 갑옷 전시 + 등급별 속도

    private func runHorseArmor() {
        let alert = NSAlert()
        alert.messageText = "🐴 말 갑옷 선택"
        alert.informativeText = "전시할 갑옷 등급을 골라줘! (말이 없어서 전시만 해)"
        alert.addButton(withTitle: "💎 다이아")
        alert.addButton(withTitle: "🪙 금")
        alert.addButton(withTitle: "⛓️ 철")
        let resp = alert.runModal()
        let tier: String
        let speed: String
        switch resp {
        case .alertFirstButtonReturn: tier = "다이아"; speed = "⚡ 번개처럼 빨라!"
        case .alertSecondButtonReturn: tier = "금"; speed = "🐇 토끼처럼 빨라!"
        default: tier = "철"; speed = "🐢 튼튼하지만 느려!"
        }
        horseArmorTier = tier
        if let h = horseStand, h.isVisible { h.close(); horseStand = nil }
        horseStand = nil
        let w = EHorseArmorWindow(startPos: spawnPos(dx: 60), tier: tier)
        horseStand = w
        w.start()
        RewardCenter.say("🐴 \(tier) 갑옷 장착! \(speed)")
        SoundAndEffectsManager.shared.play(.chime)
    }

    // MARK: - 🫏 당나귀: 클릭 3회 길들이기 + 상자 15칸 XP 뱅크(입출금)

    private func toggleDonkey() {
        if let w = donkey, w.isVisible {
            w.close(); donkey = nil; return
        }
        donkey = nil
        donkeyTaps = donkeyTamed ? donkeyTaps : 0
        let w = EDonkeyWindow(startPos: spawnPos(dx: -60), tamed: donkeyTamed) { [weak self] tapped in
            self?.handleDonkeyTap(tapped)
        }
        donkey = w
        w.start()
    }

    private func handleDonkeyTap(_ w: EDonkeyWindow) {
        if !donkeyTamed {
            donkeyTaps += 1
            w.nudge()
            if donkeyTaps >= 3 {
                donkeyTamed = true
                donkeyBank = 0
                w.setTamed(true)
                RewardCenter.grant(xp: 3, "🫏 길들였다! 상자 15칸 뱅크 개방!")
                SoundAndEffectsManager.shared.play(.chime)
            } else {
                RewardCenter.say("🫏 낯가림 중... (\(donkeyTaps)/3)")
                SoundAndEffectsManager.shared.play(.pop)
            }
            return
        }
        // 길들임 후: 클릭마다 XP 1 입금, 15칸 차면 전액 출금
        if donkeyBank < 15 {
            donkeyBank += 1
            w.nudge()
            if donkeyBank >= 15 {
                donkeyBank = 0
                RewardCenter.grant(xp: 15, "🫏 📦 상자 가득! 출금 +15XP!")
                SoundAndEffectsManager.shared.play(.chime)
            } else {
                RewardCenter.say("🫏 📦 입금 \(donkeyBank)/15")
                SoundAndEffectsManager.shared.play(.pop)
            }
        }
    }

    // MARK: - 🐎 노새: 깡충 점프 3단 연출 + 최고 기록(메모리)

    private func toggleMule() {
        if let w = mule, w.isVisible {
            w.close(); mule = nil; return
        }
        mule = nil
        let w = EMuleWindow(startPos: spawnPos(dx: 60)) { [weak self] tapped, height in
            self?.handleMuleTap(tapped, height: height)
        }
        mule = w
        w.start()
    }

    private func handleMuleTap(_ w: EMuleWindow, height: CGFloat) {
        if height > muleBest {
            muleBest = height
            RewardCenter.grant(xp: 2, "🐎 신기록! \(Int(height))pt 깡충!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("🐎 깡충! \(Int(height))pt (최고 \(Int(muleBest)))")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 💀 스켈레톤마: 뇌우에만 소환 + 번개 연출 + 탑승 토글

    private func toggleSkeletonHorse() {
        if let w = skeletonHorse, w.isVisible {
            w.close(); skeletonHorse = nil; return
        }
        guard WeatherManager.shared.isThunder else {
            RewardCenter.say("💀 ⛈️ 뇌우가 쳐야 소환돼! (날씨 대기 중)")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        skeletonHorse = nil
        skeletonRiding = false
        let w = ESkeletonHorseWindow(startPos: spawnPos(dx: 0)) { [weak self] tapped in
            self?.handleSkeletonTap(tapped)
        }
        skeletonHorse = w
        w.startWithLightning()
        RewardCenter.say("💀 ⚡ 번개와 함께 나타났다!")
    }

    private func handleSkeletonTap(_ w: ESkeletonHorseWindow) {
        skeletonRiding.toggle()
        w.setRiding(skeletonRiding)
        if skeletonRiding {
            RewardCenter.say("💀 해골마 탑승! 덜컹덜컹!")
            SoundAndEffectsManager.shared.play(.gulp)
        } else {
            RewardCenter.say("💀 해골마에서 내렸다.")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🧟 좀비마: 10월 또는 밤에만 소환 + 무적 + 탑승 토글

    private func toggleZombieHorse() {
        if let w = zombieHorse, w.isVisible {
            // 무적: 클릭해도 안 사라짐 — 토글 대신 탑승 전환
            handleZombieTap(w)
            return
        }
        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .hour], from: Date())
        let isOctober = (comps.month == 10)
        let hour = comps.hour ?? 12
        let isNight = (hour >= 18 || hour < 6)
        guard isOctober || isNight else {
            RewardCenter.say("🧟 10월이나 밤에만 나타나... 🌙")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        zombieHorse = nil
        zombieRiding = false
        let w = EZombieHorseWindow(startPos: spawnPos(dx: -40)) { [weak self] tapped in
            self?.handleZombieTap(tapped)
        }
        zombieHorse = w
        w.start()
        RewardCenter.say("🧟 무적의 좀비마 등장! (클릭해도 안 사라져!)")
        SoundAndEffectsManager.shared.play(.chime)
    }

    private func handleZombieTap(_ w: EZombieHorseWindow) {
        zombieRiding.toggle()
        w.setRiding(zombieRiding)
        if zombieRiding {
            RewardCenter.say("🧟 좀비마 탑승! 무적 질주!")
            SoundAndEffectsManager.shared.play(.gulp)
        } else {
            RewardCenter.say("🧟 좀비마는 사라지지 않아... (무적)")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 🦜 앵무새 모방: 랜덤 몹 울음소리 5종 순환 + 파티클 +1XP

    public static let eMimicSounds: [String] = [
        "🐺 아우우우!",
        "🐱 야옹냐옹!",
        "💥 쉬이이익...",
        "🐮 음머어어!",
        "🧟 으어어어!",
    ]

    private func toggleMimic() {
        if let w = mimic, w.isVisible {
            w.close(); mimic = nil; return
        }
        mimic = nil
        let w = EParrotMimicWindow(startPos: spawnPos(dx: 100)) { [weak self] tapped in
            self?.handleMimicTap(tapped)
        }
        mimic = w
        w.start()
    }

    private func handleMimicTap(_ w: EParrotMimicWindow) {
        let sound = Self.eMimicSounds[mimicIndex % Self.eMimicSounds.count]
        mimicIndex += 1
        w.chirp()
        RewardCenter.grant(xp: 1, "🦜 \(sound)")
        SoundAndEffectsManager.shared.play(.pop)
    }
}

// MARK: - 🛡️ 늑대 갑옷 전시대

public final class EWolfArmorStandWindow: NSPanel {
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: EWolfArmorStandDrawView?

    public init(startPos: CGPoint) {
        super.init(
            contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: 72, height: 60),
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
        let view = EWolfArmorStandDrawView(frame: NSRect(origin: .zero, size: NSSize(width: 72, height: 60)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.shine = sin(self.phase * 3.0)
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

private final class EWolfArmorStandDrawView: NSView {
    var shine: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 전시대
        ctx.setFillColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 2, width: 12, height: 22))
        ctx.fillEllipse(in: CGRect(x: 18, y: 0, width: 36, height: 8))
        // 갑옷 몸통 (철빛 + 가죽 끈)
        ctx.setFillColor(red: 0.70, green: 0.72, blue: 0.76, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 24, width: 32, height: 24))
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 30, width: 32, height: 5))
        ctx.fill(CGRect(x: 20, y: 39, width: 32, height: 5))
        // 광택
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35 + 0.25 * shine)
        ctx.fill(CGRect(x: 24, y: 26, width: 6, height: 20))
        // 🛡️ 문양
        ctx.setFillColor(red: 0.20, green: 0.45, blue: 0.90, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 31, y: 32, width: 10, height: 10))
    }
}

// MARK: - 🦔 아르마딜로: 사막 배회 + 몸말기

public final class EArmadilloWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (EArmadilloWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var curlLeft: TimeInterval = 0
    private var drawView: EArmadilloDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 44

    public init(startPos: CGPoint, onTap: @escaping (EArmadilloWindow) -> Void) {
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
        let view = EArmadilloDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.curlLeft > 0 { self.curlLeft -= 1.0 / 60.0 }
            if self.curlLeft <= 0 {
                if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                    self.dir = Bool.random() ? 1 : -1
                }
                self.position.x += self.dir * 26.0 / 60.0
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.curled = self.curlLeft > 0
            self.drawView?.step = sin(self.phase * 5.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func curlUp() {
        curlLeft = 1.2
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

private final class EArmadilloDrawView: NSView {
    var facingRight = true
    var curled = false
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        if curled {
            // 몸말기: 둥근 공 + 껍질 무늬
            ctx.setFillColor(red: 0.72, green: 0.55, blue: 0.38, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 14, y: 4, width: 36, height: 32))
            ctx.setStrokeColor(red: 0.50, green: 0.36, blue: 0.22, alpha: 1.0)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: 20, y: 10, width: 24, height: 20))
            ctx.strokeEllipse(in: CGRect(x: 26, y: 15, width: 12, height: 10))
        } else {
            // 사막 배회: 갈색 몸 + 귀 + 꼬리
            ctx.setFillColor(red: 0.72, green: 0.55, blue: 0.38, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 10, y: 10, width: 38, height: 22))
            ctx.setFillColor(red: 0.80, green: 0.63, blue: 0.45, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 42, y: 16, width: 14, height: 12))
            // 귀
            ctx.fill(CGRect(x: 44, y: 27, width: 4, height: 8))
            ctx.fill(CGRect(x: 50, y: 27, width: 4, height: 8))
            // 눈
            ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 51, y: 21, width: 3, height: 3))
            // 껍질 줄무늬
            ctx.setStrokeColor(red: 0.50, green: 0.36, blue: 0.22, alpha: 1.0)
            ctx.setLineWidth(1.5)
            for x in [22, 30, 38] as [CGFloat] {
                ctx.move(to: CGPoint(x: x, y: 12))
                ctx.addLine(to: CGPoint(x: x, y: 30))
                ctx.strokePath()
            }
            // 다리 + 꼬리
            ctx.setFillColor(red: 0.62, green: 0.46, blue: 0.30, alpha: 1.0)
            let lift = step * 1.5
            ctx.fill(CGRect(x: 16, y: 2 + (lift > 0 ? lift : 0), width: 7, height: 9))
            ctx.fill(CGRect(x: 34, y: 2 + (lift < 0 ? -lift : 0), width: 7, height: 9))
            ctx.fill(CGRect(x: 4, y: 12, width: 8, height: 5))
        }
        ctx.restoreGState()
    }
}

// MARK: - 🎁 고양이 선물 상자

public final class EGiftCatWindow: NSPanel {
    private let onTap: () -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: EGiftCatDrawView?

    public init(startPos: CGPoint, onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - 30, y: startPos.y, width: 60, height: 56),
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
        let view = EGiftCatDrawView(frame: NSRect(origin: .zero, size: NSSize(width: 60, height: 56)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 2.5) * 2.0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onTap()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class EGiftCatDrawView: NSView {
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 고양이 머리
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.60, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 18, y: 32 + bob, width: 24, height: 18))
        ctx.fill(CGRect(x: 20, y: 46 + bob, width: 8, height: 8))
        ctx.fill(CGRect(x: 32, y: 46 + bob, width: 8, height: 8))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 25, y: 40 + bob, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 32, y: 40 + bob, width: 3, height: 3))
        // 선물 상자
        ctx.setFillColor(red: 0.90, green: 0.30, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 6, width: 36, height: 26))
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 27, y: 6, width: 6, height: 26))
        ctx.fill(CGRect(x: 12, y: 16, width: 36, height: 6))
        // 리본
        ctx.fillEllipse(in: CGRect(x: 22, y: 32, width: 8, height: 6))
        ctx.fillEllipse(in: CGRect(x: 30, y: 32, width: 8, height: 6))
    }
}

// MARK: - 🐠 열대어 어항

public final class ETropicalFishWindow: NSPanel {
    private let onTap: (ETropicalFishWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var flashLeft: TimeInterval = 0
    private var splashLeft: TimeInterval = 0
    private var drawView: ETropicalFishDrawView?

    public init(startPos: CGPoint, onTap: @escaping (ETropicalFishWindow) -> Void) {
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - 40, y: startPos.y, width: 80, height: 56),
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
        let view = ETropicalFishDrawView(frame: NSRect(origin: .zero, size: NSSize(width: 80, height: 56)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.flashLeft > 0 { self.flashLeft -= 1.0 / 60.0 }
            if self.splashLeft > 0 { self.splashLeft -= 1.0 / 60.0 }
            self.drawView?.swim = sin(self.phase * 4.0) * 8.0
            self.drawView?.flash = self.flashLeft > 0
            self.drawView?.splash = self.splashLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func caughtFlash() {
        flashLeft = 0.8
    }

    public func splash() {
        splashLeft = 0.6
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

private final class ETropicalFishDrawView: NSView {
    var swim: CGFloat = 0
    var flash = false
    var splash = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 물통 어항
        ctx.setFillColor(red: 0.45, green: 0.70, blue: 0.95, alpha: 0.55)
        ctx.fillEllipse(in: CGRect(x: 6, y: 4, width: 68, height: 40))
        // 열대어 (무지개 줄무늬)
        let fx: CGFloat = 40 + swim
        ctx.setFillColor(red: 1.0, green: 0.55, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: fx - 16, y: 22, width: 28, height: 14))
        ctx.setFillColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: fx - 6, y: 22, width: 6, height: 14))
        ctx.setFillColor(red: 1.0, green: 0.90, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: fx - 16, y: 26, width: 28, height: 4))
        // 꼬리 + 눈
        ctx.setFillColor(red: 1.0, green: 0.40, blue: 0.50, alpha: 1.0)
        ctx.fill(CGRect(x: fx - 24, y: 23, width: 9, height: 12))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: fx + 6, y: 28, width: 3, height: 3))
        // 기포
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: 20, y: 40, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 56, y: 42, width: 3, height: 3))
        if flash {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 0.6, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: fx - 20, y: 16, width: 40, height: 26))
        }
        if splash {
            ctx.setFillColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.9)
            for x in [16, 30, 44, 58] as [CGFloat] {
                ctx.fill(CGRect(x: x, y: 46, width: 3, height: 8))
            }
        }
    }
}

// MARK: - 🐴 말 갑옷 전시대 (철·금·다이아)

public final class EHorseArmorWindow: NSPanel {
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: EHorseArmorDrawView?

    public init(startPos: CGPoint, tier: String) {
        super.init(
            contentRect: NSRect(x: startPos.x - 44, y: startPos.y, width: 88, height: 64),
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
        let view = EHorseArmorDrawView(frame: NSRect(origin: .zero, size: NSSize(width: 88, height: 64)), tier: tier)
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.shine = sin(self.phase * 2.0)
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

private final class EHorseArmorDrawView: NSView {
    var shine: CGFloat = 0
    private let tier: String

    init(frame: NSRect, tier: String) {
        self.tier = tier
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 말 몸통 실루엣 (갈색)
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 14, y: 16, width: 52, height: 26))
        ctx.fillEllipse(in: CGRect(x: 60, y: 26, width: 18, height: 16))
        // 갑옷 색상 (등급별)
        switch tier {
        case "다이아":
            ctx.setFillColor(red: 0.35, green: 0.85, blue: 0.90, alpha: 1.0)
        case "금":
            ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 1.0)
        default:
            ctx.setFillColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 18, y: 20, width: 44, height: 18))
        // 광택
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3 + 0.25 * shine)
        ctx.fill(CGRect(x: 24, y: 22, width: 6, height: 14))
        // 다리
        ctx.setFillColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 1.0)
        for x in [22, 34, 50, 60] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 7, height: 15))
        }
    }
}

// MARK: - 🫏 당나귀: 길들이기 + XP 뱅크

public final class EDonkeyWindow: NSPanel {
    private let onTap: (EDonkeyWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var hopLeft: TimeInterval = 0
    private var tamed: Bool
    private var drawView: EDonkeyDrawView?
    public var position: CGPoint
    private let panelW: CGFloat = 76
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, tamed: Bool, onTap: @escaping (EDonkeyWindow) -> Void) {
        self.position = startPos
        self.tamed = tamed
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
        let view = EDonkeyDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.hopLeft > 0 { self.hopLeft -= 1.0 / 60.0 }
            if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 16.0 / 60.0
            let hop: CGFloat = self.hopLeft > 0 ? 10.0 : 0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hop))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.tamed = self.tamed
            self.drawView?.step = sin(self.phase * 3.5)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func nudge() {
        hopLeft = 0.4
    }

    public func setTamed(_ v: Bool) {
        tamed = v
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

private final class EDonkeyDrawView: NSView {
    var facingRight = true
    var tamed = false
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통 (회갈색)
        ctx.setFillColor(red: 0.62, green: 0.58, blue: 0.54, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 14, width: 46, height: 24))
        // 머리 + 긴 귀
        ctx.fillEllipse(in: CGRect(x: 52, y: 22, width: 16, height: 14))
        ctx.fill(CGRect(x: 54, y: 34, width: 4, height: 12))
        ctx.fill(CGRect(x: 60, y: 34, width: 4, height: 12))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 61, y: 27, width: 3, height: 3))
        // 길들이면 상자 표시, 아니면 물음표
        if tamed {
            ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.20, alpha: 1.0)
            ctx.fill(CGRect(x: 22, y: 34, width: 20, height: 14))
            ctx.setFillColor(red: 0.35, green: 0.24, blue: 0.12, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 34, width: 4, height: 14))
        } else {
            ctx.setFillColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 28, y: 40, width: 8, height: 8))
        }
        // 다리
        ctx.setFillColor(red: 0.55, green: 0.51, blue: 0.47, alpha: 1.0)
        let lift = step * 1.5
        ctx.fill(CGRect(x: 16, y: 2 + (lift > 0 ? lift : 0), width: 7, height: 13))
        ctx.fill(CGRect(x: 30, y: 2 + (lift < 0 ? -lift : 0), width: 7, height: 13))
        ctx.fill(CGRect(x: 44, y: 2 + (lift > 0 ? lift : 0), width: 7, height: 13))
        ctx.restoreGState()
    }
}

// MARK: - 🐎 노새: 깡충 3단 점프 + 최고 기록

public final class EMuleWindow: NSPanel {
    private let onTap: (EMuleWindow, CGFloat) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var jumpLeft: TimeInterval = 0
    private var jumpHeight: CGFloat = 0
    private var drawView: EMuleDrawView?
    public var position: CGPoint
    private let panelW: CGFloat = 76
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (EMuleWindow, CGFloat) -> Void) {
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
        let view = EMuleDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            var lift: CGFloat = 0
            if self.jumpLeft > 0 {
                self.jumpLeft -= 1.0 / 60.0
                // 3단 점프 포물선
                let p = 1.0 - self.jumpLeft / 0.9
                lift = sin(p * Double.pi) * self.jumpHeight
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + lift))
            self.drawView?.lift = lift
            self.drawView?.step = sin(self.phase * 6.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        // 깡충 점프: 60~180 랜덤 높이
        jumpHeight = CGFloat.random(in: 60...180)
        jumpLeft = 0.9
        SoundAndEffectsManager.shared.play(.pop)
        onTap(self, jumpHeight)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class EMuleDrawView: NSView {
    var lift: CGFloat = 0
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 짙은 갈색 몸
        ctx.setFillColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 14, width: 48, height: 24))
        ctx.fillEllipse(in: CGRect(x: 54, y: 22, width: 15, height: 13))
        // 귀
        ctx.fill(CGRect(x: 56, y: 34, width: 4, height: 11))
        ctx.fill(CGRect(x: 61, y: 34, width: 4, height: 11))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 62, y: 27, width: 3, height: 3))
        // 다리 (점프 중 쭉)
        ctx.setFillColor(red: 0.38, green: 0.27, blue: 0.17, alpha: 1.0)
        let stretch: CGFloat = lift > 4 ? 6.0 : 0
        for x in [16, 28, 42, 52] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2 - stretch, width: 7, height: 13 + stretch))
        }
        // 점프 궤적선
        if lift > 4 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
            ctx.fillEllipse(in: CGRect(x: 30, y: 2, width: 6, height: 6))
            ctx.fillEllipse(in: CGRect(x: 24, y: 6, width: 4, height: 4))
        }
    }
}

// MARK: - 💀 스켈레톤마: 뇌우 소환 + 번개 + 탑승

public final class ESkeletonHorseWindow: NSPanel {
    private let onTap: (ESkeletonHorseWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var boltLeft: TimeInterval = 0
    private var riding = false
    private var drawView: ESkeletonHorseDrawView?
    public var position: CGPoint
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (ESkeletonHorseWindow) -> Void) {
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
        let view = ESkeletonHorseDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func startWithLightning() {
        orderFrontRegardless()
        boltLeft = 0.7
        SoundAndEffectsManager.shared.play(.chime)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.boltLeft > 0 { self.boltLeft -= 1.0 / 60.0 }
            let speed: CGFloat = self.riding ? 90 : 30
            if Int(self.phase) % 4 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * speed / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.riding = self.riding
            self.drawView?.bolt = self.boltLeft > 0
            self.drawView?.step = sin(self.phase * 6.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func setRiding(_ v: Bool) {
        riding = v
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

private final class ESkeletonHorseDrawView: NSView {
    var facingRight = true
    var riding = false
    var bolt = false
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 해골 몸통 (회백색 + 갈비뼈 줄)
        ctx.setFillColor(red: 0.88, green: 0.88, blue: 0.86, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 14, width: 48, height: 22))
        ctx.setStrokeColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
        ctx.setLineWidth(1.5)
        for x in [22, 30, 38, 46] as [CGFloat] {
            ctx.move(to: CGPoint(x: x, y: 16))
            ctx.addLine(to: CGPoint(x: x, y: 34))
            ctx.strokePath()
        }
        // 해골 머리 + 푸른 눈
        ctx.setFillColor(red: 0.92, green: 0.92, blue: 0.90, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 58, y: 22, width: 16, height: 14))
        ctx.setFillColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 65, y: 28, width: 4, height: 4))
        // 뼈다리
        ctx.setFillColor(red: 0.82, green: 0.82, blue: 0.80, alpha: 1.0)
        let lift = step * 2.0
        ctx.fill(CGRect(x: 18, y: 2 + (lift > 0 ? lift : 0), width: 5, height: 13))
        ctx.fill(CGRect(x: 30, y: 2 + (lift < 0 ? -lift : 0), width: 5, height: 13))
        ctx.fill(CGRect(x: 44, y: 2 + (lift > 0 ? lift : 0), width: 5, height: 13))
        ctx.fill(CGRect(x: 54, y: 2 + (lift < 0 ? -lift : 0), width: 5, height: 13))
        // 탑승자
        if riding {
            ctx.setFillColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 36, width: 12, height: 14))
            ctx.fillEllipse(in: CGRect(x: 30, y: 48, width: 12, height: 10))
        }
        // 번개 볼트
        if bolt {
            ctx.setStrokeColor(red: 1.0, green: 0.95, blue: 0.40, alpha: 1.0)
            ctx.setLineWidth(3.0)
            ctx.move(to: CGPoint(x: 40, y: 64))
            ctx.addLine(to: CGPoint(x: 34, y: 50))
            ctx.addLine(to: CGPoint(x: 40, y: 46))
            ctx.addLine(to: CGPoint(x: 34, y: 34))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}

// MARK: - 🧟 좀비마: 무적 + 탑승 토글

public final class EZombieHorseWindow: NSPanel {
    private let onTap: (EZombieHorseWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var riding = false
    private var drawView: EZombieHorseDrawView?
    public var position: CGPoint
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (EZombieHorseWindow) -> Void) {
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
        let view = EZombieHorseDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase) % 6 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            let speed: CGFloat = self.riding ? 70 : 20
            self.position.x += self.dir * speed / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.riding = self.riding
            self.drawView?.step = sin(self.phase * 4.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func setRiding(_ v: Bool) {
        riding = v
    }

    public override func mouseDown(with event: NSEvent) {
        // 무적: 클릭해도 닫히지 않고 탑승만 토글
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class EZombieHorseDrawView: NSView {
    var facingRight = true
    var riding = false
    var step: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 좀비마 몸통 (썩은 초록)
        ctx.setFillColor(red: 0.35, green: 0.55, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 14, width: 48, height: 22))
        // 상처 자국
        ctx.setFillColor(red: 0.55, green: 0.20, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 28, y: 22, width: 8, height: 5))
        ctx.fill(CGRect(x: 44, y: 26, width: 6, height: 5))
        // 머리 + 붉은 눈
        ctx.setFillColor(red: 0.38, green: 0.58, blue: 0.38, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 58, y: 22, width: 16, height: 14))
        ctx.setFillColor(red: 0.95, green: 0.15, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 65, y: 28, width: 4, height: 4))
        // 다리
        ctx.setFillColor(red: 0.30, green: 0.48, blue: 0.30, alpha: 1.0)
        let lift = step * 1.5
        ctx.fill(CGRect(x: 18, y: 2 + (lift > 0 ? lift : 0), width: 6, height: 13))
        ctx.fill(CGRect(x: 30, y: 2 + (lift < 0 ? -lift : 0), width: 6, height: 13))
        ctx.fill(CGRect(x: 44, y: 2 + (lift > 0 ? lift : 0), width: 6, height: 13))
        // 탑승자
        if riding {
            ctx.setFillColor(red: 0.30, green: 0.50, blue: 0.90, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 36, width: 12, height: 14))
            ctx.fillEllipse(in: CGRect(x: 30, y: 48, width: 12, height: 10))
        }
        // 무적 쉴드 반짝임
        ctx.setStrokeColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.7)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: 8, y: 8, width: 68, height: 40))
        ctx.restoreGState()
    }
}

// MARK: - 🦜 앵무새 모방: 몹 울음소리 순환 + 파티클

public final class EParrotMimicWindow: NSPanel {
    private let onTap: (EParrotMimicWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var chirpLeft: TimeInterval = 0
    private var drawView: EParrotMimicDrawView?

    public init(startPos: CGPoint, onTap: @escaping (EParrotMimicWindow) -> Void) {
        self.onTap = onTap
        super.init(
            contentRect: NSRect(x: startPos.x - 28, y: startPos.y, width: 56, height: 52),
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
        let view = EParrotMimicDrawView(frame: NSRect(origin: .zero, size: NSSize(width: 56, height: 52)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.chirpLeft > 0 { self.chirpLeft -= 1.0 / 60.0 }
            self.drawView?.wing = sin(self.phase * 8.0)
            self.drawView?.chirping = self.chirpLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func chirp() {
        chirpLeft = 0.8
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

private final class EParrotMimicDrawView: NSView {
    var wing: CGFloat = 0
    var chirping = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 앵무새 몸 (빨강·파랑)
        ctx.setFillColor(red: 0.90, green: 0.25, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 10, width: 24, height: 28))
        ctx.setFillColor(red: 0.25, green: 0.50, blue: 0.95, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 10, width: 24, height: 12))
        // 날개 (펄럭임)
        let flap = wing * 4.0
        ctx.setFillColor(red: 0.20, green: 0.70, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 18 + flap, width: 12, height: 16))
        ctx.fillEllipse(in: CGRect(x: 38, y: 18 - flap, width: 12, height: 16))
        // 부리 + 눈
        ctx.setFillColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 30, width: 8, height: 6))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 24, y: 36, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 29, y: 36, width: 3, height: 3))
        // 울음 파티클 음표
        if chirping {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
            ctx.fillEllipse(in: CGRect(x: 42, y: 40, width: 6, height: 6))
            ctx.fill(CGRect(x: 46, y: 40, width: 2, height: 10))
            ctx.fillEllipse(in: CGRect(x: 10, y: 44, width: 5, height: 5))
        }
    }
}
