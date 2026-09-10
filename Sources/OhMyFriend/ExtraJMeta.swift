import AppKit
import CoreGraphics
import Foundation

// J분야 10종: 좀비치료·전직소·명찰·제도대·결투장·경마·하드코어·콘테스트·통계실·낚시왕 + MetaJManager.
// AppController "🎉 추가 모션" 서브메뉴에서 MetaJManager.shared.entries()로 호출한다.

public final class MetaJManager {
    public static let shared = MetaJManager()

    private let timeKey = "MetaJStatsTime"
    private let countKey = "MetaJStatsCount"
    private let fishKey = "MetaJFishingBest"

    private var sessionStart: TimeInterval
    private var isRegular = false
    private var isHardcore = false
    private var hardcoreTimer: Timer?
    private var hardcoreStart: Date?

    private var cure: JZombieCureWindow?
    private var job: JJobWindow?
    private var nameTag: JNameTagWindow?
    private var cart: JCartographyWindow?
    private var arena: JArenaWindow?
    private var race: JRaceWindow?
    private var badge: JHardcoreBadgeWindow?
    private var contest: JContestWindow?
    private var stats: JStatsWindow?
    private var fishing: JFishingKingWindow?
    private var fishDex = Set<String>()

    private init() {
        sessionStart = Date().timeIntervalSinceReferenceDate
    }

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ [weak self] in self?.cureTitle() ?? "🧟 주민 치료" }, { [weak self] in self?.toggleCure() }),
            ExtraMenuEntry({ "👨‍🌾 전직소" }, { [weak self] in self?.toggleJob() }),
            ExtraMenuEntry({ "🏷️ 명찰" }, { [weak self] in self?.toggleNameTag() }),
            ExtraMenuEntry({ "🗺️ 제도대" }, { [weak self] in self?.toggleCart() }),
            ExtraMenuEntry({ "⚔️ 결투장" }, { [weak self] in self?.toggleArena() }),
            ExtraMenuEntry({ "🏇 경마" }, { [weak self] in self?.toggleRace() }),
            ExtraMenuEntry({ [weak self] in self?.hardcoreTitle() ?? "💀 하드코어" }, { [weak self] in self?.toggleHardcore() }),
            ExtraMenuEntry({ "🎨 콘테스트" }, { [weak self] in self?.toggleContest() }),
            ExtraMenuEntry({ "📊 통계실" }, { [weak self] in self?.toggleStats() }),
            ExtraMenuEntry({ "🎣 낚시왕" }, { [weak self] in self?.toggleFishing() }),
        ]
    }

    private func cureTitle() -> String {
        return isRegular ? "🧟 주민 치료 (단골)" : "🧟 주민 치료"
    }

    private func hardcoreTitle() -> String {
        return isHardcore ? "💀 하드코어 (ON)" : "💀 하드코어"
    }

    private func trackRun() {
        let n = UserDefaults.standard.integer(forKey: countKey) + 1
        UserDefaults.standard.set(n, forKey: countKey)
    }

    private func grantJ(xp: Int, _ emoji: String) {
        RewardCenter.grant(xp: isHardcore ? xp * 2 : xp, emoji)
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

    // MARK: - 1. 좀비 주민 치료

    private func toggleCure() {
        trackRun()
        if let w = cure, w.isVisible {
            w.close(); cure = nil; return
        }
        cure = nil
        let w = JZombieCureWindow(startPos: spawnPos(dx: -60)) { [weak self] win in
            self?.handleCureTap(win)
        }
        cure = w
        w.start()
    }

    private func handleCureTap(_ w: JZombieCureWindow) {
        if w.isCured {
            RewardCenter.say("🧑‍🌾 고마워요, 단골님! 평생 반값!")
            SoundAndEffectsManager.shared.play(.heart)
            return
        }
        if RewardCenter.heldItemName?() == "황금 사과 🍎" {
            w.cure()
            isRegular = true
            grantJ(xp: 4, "🧟 치료 완료! 평생 반값 단골!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("🧟 황금 사과 🍎를 들고 클릭!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 2. 전직소 (직업대 13종)

    private let jobs: [(String, String, String)] = [
        ("농부", "🌾", "🌾 밀 선물!"), ("어부", "🎣", "🎣 낚싯대 선물!"),
        ("사서", "📚", "📚 책 선물!"), ("성직자", "✨", "✨ 엔더 진주 선물!"),
        ("갑옷상", "🛡️", "🛡️ 방패 선물!"), ("무기상", "🗡️", "🗡️ 철검 선물!"),
        ("도구상", "⛏️", "⛏️ 곡괭이 선물!"), ("석공", "🧱", "🧱 벽돌 선물!"),
        ("화살상", "🏹", "🏹 활 선물!"), ("가죽상", "🐄", "🐄 가죽 선물!"),
        ("양치기", "🐑", "🐑 양털 선물!"), ("정육점", "🥩", "🥩 스테이크 선물!"),
        ("지도제작자", "🗺️", "🗺️ 지도 선물!"),
    ]

    private func toggleJob() {
        trackRun()
        if let w = job, w.isVisible {
            w.close(); job = nil; return
        }
        job = nil
        let alert = NSAlert()
        alert.messageText = "👨‍🌾 전직할 직업을 고르세요 (13종)"
        alert.addButton(withTitle: "전직")
        alert.addButton(withTitle: "취소")
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        popup.addItems(withTitles: jobs.map { "\($0.1) \($0.0)" })
        alert.accessoryView = popup
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let idx = popup.indexOfSelectedItem
        guard idx >= 0 && idx < jobs.count else { return }
        let picked = jobs[idx]
        let w = JJobWindow(floorPos: spawnPos(dx: 60), emoji: picked.1, job: picked.0)
        job = w
        w.place()
        grantJ(xp: 2, "👨‍🌾 \(picked.0)으로 전직! \(picked.2)")
        SoundAndEffectsManager.shared.play(.chime)
    }

    // MARK: - 3. 명찰

    private func toggleNameTag() {
        trackRun()
        if let w = nameTag, w.isVisible {
            w.close(); nameTag = nil; return
        }
        nameTag = nil
        let alert = NSAlert()
        alert.messageText = "🏷️ 명찰에 새길 이름"
        alert.addButton(withTitle: "붙이기")
        alert.addButton(withTitle: "취소")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = "멍멍이"
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.isEmpty ? "멍멍이" : field.stringValue
        let w = JNameTagWindow(startPos: spawnPos(dx: 0), petName: name) { tapped in
            RewardCenter.say("🏷️ \(tapped.petName)! ❤️")
            SoundAndEffectsManager.shared.play(.heart)
            tapped.bounce()
        }
        nameTag = w
        w.start()
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - 4. 제도대 (9칸 지도)

    private func toggleCart() {
        trackRun()
        if let w = cart, w.isVisible {
            w.close(); cart = nil; return
        }
        cart = nil
        let w = JCartographyWindow(floorPos: spawnPos(dx: -40)) { [weak self] done in
            guard done else {
                SoundAndEffectsManager.shared.play(.pop)
                return
            }
            self?.grantJ(xp: 5, "🗺️ 지도 완성! 위대한 탐험가!")
            SoundAndEffectsManager.shared.play(.chime)
        }
        cart = w
        w.place()
    }

    // MARK: - 5. 결투장 (검투사 2명 토너먼트)

    private func toggleArena() {
        trackRun()
        if let w = arena, w.isVisible {
            w.close(); arena = nil; return
        }
        arena = nil
        let w = JArenaWindow(floorPos: spawnPos(dx: 40)) { [weak self] winner in
            self?.grantJ(xp: 4, "⚔️ \(winner) 우승! 🏆 트로피!")
            SoundAndEffectsManager.shared.play(.chime)
        }
        arena = w
        w.start()
    }

    // MARK: - 6. 경마 (3종 레이스 + 베팅)

    private func toggleRace() {
        trackRun()
        if let w = race, w.isVisible {
            w.close(); race = nil; return
        }
        race = nil
        let alert = NSAlert()
        alert.messageText = "🏇 우승마에 베팅하세요 (맞히면 3배 XP)"
        alert.addButton(withTitle: "1번 백마")
        alert.addButton(withTitle: "2번 흑마")
        alert.addButton(withTitle: "3번 적토마")
        let order = alert.runModal()
        let bet: Int
        switch order {
        case .alertFirstButtonReturn: bet = 0
        case .alertSecondButtonReturn: bet = 1
        default: bet = 2
        }
        let w = JRaceWindow(floorPos: spawnPos(dx: 0), bet: bet) { [weak self] won, winnerName in
            if won {
                self?.grantJ(xp: 3, "🏇 적중! \(winnerName) 우승! 3배!")
            } else {
                self?.grantJ(xp: 1, "🏇 \(winnerName) 우승! 참가상!")
            }
            SoundAndEffectsManager.shared.play(.chime)
        }
        race = w
        w.start()
    }

    // MARK: - 7. 하드코어 토글

    private func toggleHardcore() {
        trackRun()
        if isHardcore {
            setHardcore(false)
            RewardCenter.say("💀 하드코어 종료! 정산 완료!")
            SoundAndEffectsManager.shared.play(.pop)
        } else {
            setHardcore(true)
            RewardCenter.say("💀 하드코어 ON! J보상 2배!")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }

    private func setHardcore(_ on: Bool) {
        isHardcore = on
        hardcoreTimer?.invalidate()
        hardcoreTimer = nil
        if on {
            hardcoreStart = Date()
            let b = JHardcoreBadgeWindow(floorPos: spawnPos(dx: 100))
            badge = b
            b.place()
            hardcoreTimer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: false) { [weak self] _ in
                self?.setHardcore(false)
                RewardCenter.say("💀 24시간 생존! 하드코어 정산!")
                SoundAndEffectsManager.shared.play(.chime)
            }
            if let t = hardcoreTimer { RunLoop.main.add(t, forMode: .common) }
        } else {
            badge?.close()
            badge = nil
        }
    }

    // MARK: - 8. 콘테스트 (주제 3종 투표)

    private func toggleContest() {
        trackRun()
        if let w = contest, w.isVisible {
            w.close(); contest = nil; return
        }
        contest = nil
        let alert = NSAlert()
        alert.messageText = "🎨 콘테스트 주제에 투표하세요"
        alert.addButton(withTitle: "🏰 최고의 집")
        alert.addButton(withTitle: "🗡️ 최고의 검")
        alert.addButton(withTitle: "🎨 최고의 픽셀아트")
        let order = alert.runModal()
        let winner: String
        switch order {
        case .alertFirstButtonReturn: winner = "🏰"
        case .alertSecondButtonReturn: winner = "🗡️"
        default: winner = "🎨"
        }
        let w = JContestWindow(floorPos: spawnPos(dx: -80), winner: winner)
        contest = w
        w.place()
        grantJ(xp: 2, "🎨 콘테스트 참가! 우승작 \(winner)!")
        SoundAndEffectsManager.shared.play(.chime)
    }

    // MARK: - 9. 통계실

    private func toggleStats() {
        trackRun()
        if let w = stats, w.isVisible {
            w.close(); stats = nil; return
        }
        stats = nil
        let now = Date().timeIntervalSinceReferenceDate
        let total = UserDefaults.standard.double(forKey: timeKey) + (now - sessionStart)
        UserDefaults.standard.set(total, forKey: timeKey)
        sessionStart = now
        let count = UserDefaults.standard.integer(forKey: countKey)
        let rank: String
        if count >= 50 { rank = "👑 전설" }
        else if count >= 10 { rank = "⭐ 프로" }
        else { rank = "🌱 노말" }
        let w = JStatsWindow(floorPos: spawnPos(dx: 80), seconds: total, runs: count, rank: rank)
        stats = w
        w.place()
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - 10. 낚시왕 (월간 최대어 + 도감 5종)

    private let fishSpecies = ["🐟 연어", "🐡 복어", "🦈 상어", "🐠 열대어", "🐙 문어"]

    private func toggleFishing() {
        trackRun()
        if let w = fishing, w.isVisible {
            w.close(); fishing = nil; return
        }
        fishing = nil
        let month = Calendar.current.component(.month, from: Date())
        let best = UserDefaults.standard.string(forKey: fishKey) ?? "없음"
        let w = JFishingKingWindow(floorPos: spawnPos(dx: 0), month: month, best: best) { [weak self] species, size in
            self?.handleCatch(species: species, size: size)
        }
        fishing = w
        w.start()
    }

    private func handleCatch(species: String, size: Double) {
        let isNew = !fishDex.contains(species)
        fishDex.insert(species)
        let record = "\(species) \(String(format: "%.1f", size))cm"
        let prev = UserDefaults.standard.string(forKey: fishKey) ?? ""
        let prevSize = Double(prev.split(separator: " ").last?.replacingOccurrences(of: "cm", with: "") ?? "") ?? 0
        if size > prevSize {
            UserDefaults.standard.set(record, forKey: fishKey)
            fishing?.best = record
            RewardCenter.say("🎣 신기록! \(record)")
        } else {
            RewardCenter.say("🎣 \(record)!")
        }
        SoundAndEffectsManager.shared.play(.splash)
        if isNew {
            grantJ(xp: 1, "🎣 신종 발견! \(species)")
        }
        if fishDex.count >= 5 {
            grantJ(xp: 8, "🎣 도감 완성! 낚시왕 등극!")
            SoundAndEffectsManager.shared.play(.chime)
            fishDex.removeAll()
        }
    }
}

// MARK: - 1. 좀비 주민 치료 창

public final class JZombieCureWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (JZombieCureWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var curingLeft: TimeInterval = 0
    private var cured = false
    private var drawView: JZombieCureView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 64

    public var isCured: Bool { cured }

    public init(startPos: CGPoint, onTap: @escaping (JZombieCureWindow) -> Void) {
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
        let view = JZombieCureView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.curingLeft > 0 {
                self.curingLeft -= 1.0 / 60.0
                if self.curingLeft <= 0 { self.cured = true }
            }
            let shake: CGFloat = self.curingLeft > 0 ? CGFloat.random(in: -3...3) : 0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2 + shake, y: self.position.y))
            self.drawView?.cured = self.cured
            self.drawView?.curing = self.curingLeft > 0
            self.drawView?.bob = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func cure() {
        curingLeft = 1.5
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

private final class JZombieCureView: NSView {
    var cured = false
    var curing = false
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let y = 6 + bob
        if cured {
            ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.25, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.35, green: 0.65, blue: 0.40, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 20, y: y, width: 24, height: 34))
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: y + 34, width: 20, height: 18))
        if cured {
            ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: 29, y: y + 38, width: 6, height: 10))
            ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 27, y: y + 44, width: 4, height: 4))
            ctx.fillEllipse(in: CGRect(x: 33, y: y + 44, width: 4, height: 4))
        } else {
            ctx.setFillColor(red: 0.15, green: 0.45, blue: 0.20, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 27, y: y + 43, width: 5, height: 5))
            ctx.fillEllipse(in: CGRect(x: 32, y: y + 43, width: 5, height: 5))
        }
        if curing {
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 0.8)
            for i in 0..<3 {
                ctx.fillEllipse(in: CGRect(x: 12 + CGFloat(i) * 18, y: y + 52, width: 6, height: 6))
            }
        }
        if cured {
            ctx.setFillColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 46, y: y + 30, width: 8, height: 8))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            ctx.fill(CGRect(x: 49, y: y + 31, width: 2, height: 6))
            ctx.fill(CGRect(x: 47, y: y + 33, width: 6, height: 2))
        }
    }
}

// MARK: - 2. 전직소 창

public final class JJobWindow: NSPanel {
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private let emoji: String
    private let job: String
    private var drawView: JJobView?

    public init(floorPos: CGPoint, emoji: String, job: String) {
        self.emoji = emoji
        self.job = job
        let size = NSSize(width: 96, height: 72)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JJobView(frame: NSRect(origin: .zero, size: size), emoji: emoji, job: job)
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 3.0)
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

private final class JJobView: NSView {
    private let emoji: String
    private let job: String
    var bob: CGFloat = 0

    init(frame: NSRect, emoji: String, job: String) {
        self.emoji = emoji
        self.job = job
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 22 + bob, width: 80, height: 10))
        ctx.fill(CGRect(x: 12, y: 8, width: 8, height: 16))
        ctx.fill(CGRect(x: 76, y: 8, width: 8, height: 16))
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: 38, y: 30 + bob, width: 20, height: 26))
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 40, y: 52 + bob, width: 16, height: 14))
        let text = "\(emoji) \(job)" as NSString
        text.draw(at: CGPoint(x: 8, y: 0), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
    }
}

// MARK: - 3. 명찰 창 (몹 1마리 + 말풍선 명패)

public final class JNameTagWindow: NSPanel {
    public let petName: String
    public var position: CGPoint
    private let onTap: (JNameTagWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var bounceLeft: TimeInterval = 0
    private var drawView: JNameTagView?
    private let panelW: CGFloat = 96
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, petName: String, onTap: @escaping (JNameTagWindow) -> Void) {
        self.position = startPos
        self.petName = petName
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
        let view = JNameTagView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)), petName: petName)
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.bounceLeft > 0 { self.bounceLeft -= 1.0 / 60.0 }
            let hop: CGFloat = self.bounceLeft > 0 ? abs(sin(self.phase * 12.0)) * 10.0 : 0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hop))
            self.drawView?.wag = sin(self.phase * 8.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func bounce() {
        bounceLeft = 0.6
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

private final class JNameTagView: NSView {
    private let petName: String
    var wag: CGFloat = 0

    init(frame: NSRect, petName: String) {
        self.petName = petName
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
        ctx.fill(CGRect(x: 6, y: 44, width: 84, height: 22))
        ctx.setStrokeColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: 6, y: 44, width: 84, height: 22))
        let label = "🏷️ \(petName)" as NSString
        label.draw(at: CGPoint(x: 10, y: 49), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
        ctx.setFillColor(red: 0.70, green: 0.55, blue: 0.40, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30, y: 10, width: 36, height: 26))
        ctx.fillEllipse(in: CGRect(x: 56, y: 24, width: 16, height: 14))
        ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30, y: 34, width: 8, height: 10))
        ctx.fillEllipse(in: CGRect(x: 44, y: 34, width: 8, height: 10))
        ctx.setFillColor(red: 0.70, green: 0.55, blue: 0.40, alpha: 1.0)
        let tail = wag * 4.0
        ctx.fill(CGRect(x: 24 + tail, y: 14, width: 8, height: 5))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 62, y: 29, width: 4, height: 4))
    }
}

// MARK: - 4. 제도대 (9칸 탐험 지도)

public final class JCartographyWindow: NSPanel {
    private let onExplore: (Bool) -> Void
    private var explored: [String?] = Array(repeating: nil, count: 9)
    private let terrains = ["🌲", "⛰️", "🏜️", "🌊", "🍄", "❄️", "🌾", "🪨", "🏝️"]
    private var drawView: JCartographyView?
    private let cell: CGFloat = 30

    public init(floorPos: CGPoint, onExplore: @escaping (Bool) -> Void) {
        self.onExplore = onExplore
        let size = NSSize(width: 110, height: 110)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JCartographyView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
        refresh()
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
        let col = Int((loc.x - 10) / cell)
        let row = Int((loc.y - 10) / cell)
        guard col >= 0 && col < 3 && row >= 0 && row < 3 else { return }
        let idx = row * 3 + col
        guard explored[idx] == nil else { return }
        explored[idx] = terrains.randomElement() ?? "🌲"
        refresh()
        let done = !explored.contains(where: { $0 == nil })
        onExplore(done)
    }

    private func refresh() {
        drawView?.explored = explored
        drawView?.needsDisplay = true
    }
}

private final class JCartographyView: NSView {
    var explored: [String?] = Array(repeating: nil, count: 9)

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cell: CGFloat = 30
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: 102, height: 102))
        for row in 0..<3 {
            for col in 0..<3 {
                let idx = row * 3 + col
                let r = CGRect(x: 10 + CGFloat(col) * cell, y: 10 + CGFloat(row) * cell, width: cell - 2, height: cell - 2)
                if let t = explored[idx] {
                    ctx.setFillColor(red: 0.90, green: 0.85, blue: 0.70, alpha: 1.0)
                    ctx.fill(r)
                    (t as NSString).draw(at: CGPoint(x: r.minX + 5, y: r.minY + 4), withAttributes: [.font: NSFont.systemFont(ofSize: 15)])
                } else {
                    ctx.setFillColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0)
                    ctx.fill(r)
                    ("?" as NSString).draw(at: CGPoint(x: r.minX + 9, y: r.minY + 4), withAttributes: [.font: NSFont.systemFont(ofSize: 15)])
                }
            }
        }
    }
}

// MARK: - 5. 결투장 (검투사 토너먼트)

public final class JArenaWindow: NSPanel {
    private let onWinner: (String) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var hp = [3, 3]
    private var finished = false
    private var clashLeft: TimeInterval = 0
    private var drawView: JArenaView?
    private let names = ["🔴 붉은 검투사", "🔵 푸른 검투사"]

    public init(floorPos: CGPoint, onWinner: @escaping (String) -> Void) {
        self.onWinner = onWinner
        let size = NSSize(width: 140, height: 80)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JArenaView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
        refresh()
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.clashLeft > 0 {
                self.clashLeft -= 1.0 / 60.0
                self.refresh()
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        guard !finished else { return }
        let loser = Bool.random() ? 0 : 1
        hp[loser] -= 1
        clashLeft = 0.4
        SoundAndEffectsManager.shared.play(.pop)
        refresh()
        if hp[0] <= 0 || hp[1] <= 0 {
            finished = true
            let winner = hp[0] > 0 ? names[0] : names[1]
            refresh()
            onWinner(winner)
        }
    }

    private func refresh() {
        drawView?.hp = hp
        drawView?.finished = finished
        drawView?.clash = clashLeft > 0
        drawView?.bob = sin(phase * 5.0)
        drawView?.needsDisplay = true
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class JArenaView: NSView {
    var hp = [3, 3]
    var finished = false
    var clash = false
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.80, green: 0.65, blue: 0.42, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 2, width: 128, height: 22))
        let colors: [(CGFloat, CGFloat, CGFloat)] = [(0.85, 0.25, 0.25), (0.25, 0.45, 0.85)]
        for i in 0..<2 {
            let x: CGFloat = i == 0 ? 30 : 94
            let alive = hp[i] > 0
            ctx.setFillColor(red: colors[i].0, green: colors[i].1, blue: colors[i].2, alpha: alive ? 1.0 : 0.35)
            ctx.fill(CGRect(x: x, y: 24 + (clash ? 4 : 0) + bob, width: 16, height: 26))
            ctx.fill(CGRect(x: x + 2, y: 48 + bob, width: 12, height: 12))
            ctx.setFillColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0)
            ctx.fill(CGRect(x: x + (i == 0 ? 14 : -8), y: 32, width: 10, height: 3))
            for h in 0..<3 {
                if h < hp[i] {
                    ctx.setFillColor(red: 1.0, green: 0.30, blue: 0.35, alpha: 1.0)
                } else {
                    ctx.setFillColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1.0)
                }
                ctx.fillEllipse(in: CGRect(x: x - 4 + CGFloat(h) * 9, y: 16, width: 7, height: 7))
            }
        }
        if clash {
            ("💥" as NSString).draw(at: CGPoint(x: 62, y: 34), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
        }
        if finished {
            ("🏆" as NSString).draw(at: CGPoint(x: 62, y: 52), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
        }
    }
}

// MARK: - 6. 경마 (3종 10초 레이스)

public final class JRaceWindow: NSPanel {
    private let bet: Int
    private let onFinish: (Bool, String) -> Void
    private var tick: Timer?
    private var elapsed: TimeInterval = 0
    private var progress: [CGFloat] = [0, 0, 0]
    private var speeds: [CGFloat] = [22, 22, 22]
    private var finished = false
    private var drawView: JRaceView?
    private let names = ["백마", "흑마", "적토마"]
    private let duration: TimeInterval = 10

    public init(floorPos: CGPoint, bet: Int, onFinish: @escaping (Bool, String) -> Void) {
        self.bet = bet
        self.onFinish = onFinish
        let size = NSSize(width: 220, height: 84)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JRaceView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.elapsed += dt
            for i in 0..<3 {
                self.speeds[i] = CGFloat.random(in: 12...30)
                self.progress[i] += self.speeds[i] * CGFloat(dt) / (200.0 / self.duration * 10.0)
            }
            self.drawView?.progress = self.progress
            self.drawView?.needsDisplay = true
            if self.elapsed >= self.duration && !self.finished {
                self.finished = true
                t.invalidate()
                var winner = 0
                for i in 1..<3 {
                    if self.progress[i] > self.progress[winner] { winner = i }
                }
                self.drawView?.winner = winner
                self.drawView?.needsDisplay = true
                self.onFinish(winner == self.bet, self.names[winner])
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class JRaceView: NSView {
    var progress: [CGFloat] = [0, 0, 0]
    var winner: Int?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let lanes: [CGFloat] = [8, 32, 56]
        let coats: [(CGFloat, CGFloat, CGFloat)] = [(0.95, 0.95, 0.95), (0.20, 0.20, 0.22), (0.65, 0.35, 0.20)]
        ctx.setFillColor(red: 0.35, green: 0.55, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 2, width: 212, height: 76))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        ctx.fill(CGRect(x: 200, y: 2, width: 3, height: 76))
        for i in 0..<3 {
            let x = 10 + min(progress[i], 1.0) * 180
            ctx.setFillColor(red: coats[i].0, green: coats[i].1, blue: coats[i].2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: x, y: lanes[i], width: 26, height: 14))
            ctx.fillEllipse(in: CGRect(x: x + 20, y: lanes[i] + 8, width: 10, height: 9))
            ("\(i + 1)" as NSString).draw(at: CGPoint(x: x + 8, y: lanes[i] + 2), withAttributes: [.font: NSFont.systemFont(ofSize: 9)])
        }
        if let w = winner {
            ("🏆 \(w + 1)번!" as NSString).draw(at: CGPoint(x: 70, y: 66), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
        }
    }
}

// MARK: - 7. 하드코어 뱃지

public final class JHardcoreBadgeWindow: NSPanel {
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: JHardcoreBadgeView?

    public init(floorPos: CGPoint) {
        let size = NSSize(width: 44, height: 44)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JHardcoreBadgeView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.pulse = (sin(self.phase * 4.0) + 1.0) / 2.0
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

private final class JHardcoreBadgeView: NSView {
    var pulse: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: 36, height: 36))
        ctx.setFillColor(red: 1.0, green: 0.25 + pulse * 0.3, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 14, width: 20, height: 18))
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 22, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: 23, y: 22, width: 5, height: 6))
        ctx.fill(CGRect(x: 20, y: 15, width: 4, height: 4))
    }
}

// MARK: - 8. 콘테스트 우승작 창

public final class JContestWindow: NSPanel {
    private let winner: String
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: JContestView?

    public init(floorPos: CGPoint, winner: String) {
        self.winner = winner
        let size = NSSize(width: 110, height: 80)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        let view = JContestView(frame: NSRect(origin: .zero, size: size), winner: winner)
        self.drawView = view
        contentView = view
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 3.0)
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

private final class JContestView: NSView {
    private let winner: String
    var bob: CGFloat = 0

    init(frame: NSRect, winner: String) {
        self.winner = winner
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
        ctx.fill(CGRect(x: 4, y: 40 + bob, width: 102, height: 34))
        ctx.setStrokeColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: 4, y: 40 + bob, width: 102, height: 34))
        ("🏆 우승 \(winner)" as NSString).draw(at: CGPoint(x: 12, y: 50 + bob), withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
        (winner as NSString).draw(at: CGPoint(x: 42, y: 6), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
        for i in 0..<3 {
            ctx.fillEllipse(in: CGRect(x: 18 + CGFloat(i) * 30, y: 2, width: 5, height: 5))
        }
    }
}

// MARK: - 9. 통계실 창

public final class JStatsWindow: NSPanel {
    public init(floorPos: CGPoint, seconds: Double, runs: Int, rank: String) {
        let size = NSSize(width: 170, height: 96)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
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
        contentView = JStatsView(frame: NSRect(origin: .zero, size: size), seconds: seconds, runs: runs, rank: rank)
    }

    public func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
}

private final class JStatsView: NSView {
    private let seconds: Double
    private let runs: Int
    private let rank: String

    init(frame: NSRect, seconds: Double, runs: Int, rank: String) {
        self.seconds = seconds
        self.runs = runs
        self.rank = rank
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 0.95)
        ctx.fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        let mins = Int(seconds) / 60
        let hrs = mins / 60
        let time = hrs > 0 ? "\(hrs)시간 \(mins % 60)분" : "\(mins)분 \(Int(seconds) % 60)초"
        let lines = ["📊 통계실 \(rank)", "⏱️ 플레이 \(time)", "🖱️ 메뉴 실행 \(runs)회"]
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(
                at: CGPoint(x: 10, y: bounds.height - 24 - CGFloat(i) * 24),
                withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white]
            )
        }
    }
}

// MARK: - 10. 낚시왕 창 (도감 5종 + 최대어)

public final class JFishingKingWindow: NSPanel {
    public var best: String {
        didSet { drawView?.best = best; drawView?.needsDisplay = true }
    }
    private let month: Int
    private let onCatch: (String, Double) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var splashLeft: TimeInterval = 0
    private var lastCatch = ""
    private var drawView: JFishingKingView?
    private let species = ["🐟 연어", "🐡 복어", "🦈 상어", "🐠 열대어", "🐙 문어"]
    private let panelW: CGFloat = 150
    private let panelH: CGFloat = 84

    public init(floorPos: CGPoint, month: Int, best: String, onCatch: @escaping (String, Double) -> Void) {
        self.month = month
        self.best = best
        self.onCatch = onCatch
        super.init(
            contentRect: NSRect(x: floorPos.x - panelW / 2, y: floorPos.y, width: panelW, height: panelH),
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
        let view = JFishingKingView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)), month: month, best: best)
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.splashLeft > 0 { self.splashLeft -= 1.0 / 60.0 }
            self.drawView?.wave = sin(self.phase * 3.0)
            self.drawView?.splash = self.splashLeft > 0
            self.drawView?.lastCatch = self.lastCatch
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        let fish = species.randomElement() ?? "🐟 연어"
        let size = Double.random(in: 10...120)
        lastCatch = "\(fish) \(String(format: "%.1f", size))cm"
        splashLeft = 0.8
        onCatch(fish, size)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class JFishingKingView: NSView {
    private let month: Int
    var best: String
    var wave: CGFloat = 0
    var splash = false
    var lastCatch = ""

    init(frame: NSRect, month: Int, best: String) {
        self.month = month
        self.best = best
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.20, green: 0.45, blue: 0.75, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: bounds.width - 8, height: 30 + wave))
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 30, width: bounds.width - 8, height: 8))
        ctx.setStrokeColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 75, y: 60))
        ctx.addLine(to: CGPoint(x: 75, y: 34))
        ctx.strokePath()
        if splash {
            ("💦" as NSString).draw(at: CGPoint(x: 68, y: 30), withAttributes: [.font: NSFont.systemFont(ofSize: 14)])
        }
        ("🎣 \(month)월 · 최대어 \(best)" as NSString).draw(at: CGPoint(x: 6, y: 62), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
        if !lastCatch.isEmpty {
            (lastCatch as NSString).draw(at: CGPoint(x: 6, y: 44), withAttributes: [.font: NSFont.systemFont(ofSize: 10)])
        }
    }
}
