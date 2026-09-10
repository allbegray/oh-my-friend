import AppKit
import CoreGraphics

// 17차 백로그 5종(약탈자습격·피리·활공링·멍때리기·몹머리) 단일 파일.
// EventManager.shared.entries()로 메뉴에 연결한다.

// MARK: - 몹 머리 보관함 (파일 내부 public 싱글톤, 메모리 보관만)

public final class MobHeadWard {
    public static let shared = MobHeadWard()
    private init() {}

    public enum HeadKind: CaseIterable {
        case creeper
        case skeleton
        case zombie

        public var name: String {
            switch self {
            case .creeper: return "크리퍼"
            case .skeleton: return "스켈레톤"
            case .zombie: return "좀비"
            }
        }

        public var emoji: String {
            switch self {
            case .creeper: return "💥"
            case .skeleton: return "🏹"
            case .zombie: return "🧟"
            }
        }
    }

    public private(set) var owned: HeadKind?
    public private(set) var wearing: HeadKind?

    @discardableResult
    public func obtainRandom() -> HeadKind {
        let all = HeadKind.allCases
        let picked = all[Int.random(in: 0..<all.count)]
        owned = picked
        return picked
    }

    public func wear() {
        if let o = owned { wearing = o }
    }

    public func takeOff() {
        wearing = nil
    }
}

// MARK: - 약탈자 패널 (웨이브 몹, 클릭 1타 격퇴)

private final class Extra17PillagerWindow: NSPanel {
    var onTap: (() -> Void)?
    private var animTimer: Timer?
    private var phase: TimeInterval = 0
    private var drawView: Extra17PillagerDrawView?

    init(startPos: CGPoint) {
        let size = NSSize(width: 48, height: 68)
        super.init(
            contentRect: NSRect(x: startPos.x - 24, y: startPos.y, width: size.width, height: size.height),
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
        let view = Extra17PillagerDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 6.0) * 2.0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(animTimer!, forMode: .common)
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }

    func dismiss() {
        animTimer?.invalidate()
        animTimer = nil
        onTap = nil
        close()
    }

    override func close() {
        animTimer?.invalidate()
        animTimer = nil
        super.close()
    }
}

private final class Extra17PillagerDrawView: NSView {
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 몸통 (회색 코트)
        ctx.setFillColor(red: 0.45, green: 0.42, blue: 0.45, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 20 + bob, width: 20, height: 24))
        // 머리
        ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.60, alpha: 1.0)
        ctx.fill(CGRect(x: 13, y: 44 + bob, width: 22, height: 18))
        // 눈 (사나운 눈썹)
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fill(CGRect(x: 17, y: 53 + bob, width: 6, height: 3))
        ctx.fill(CGRect(x: 25, y: 53 + bob, width: 6, height: 3))
        // 석궁 (옆에 든 막대)
        ctx.setFillColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 36, y: 26 + bob, width: 4, height: 22))
        ctx.fill(CGRect(x: 30, y: 34 + bob, width: 16, height: 3))
        // 다리
        ctx.setFillColor(red: 0.35, green: 0.33, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 4, width: 7, height: 16))
        ctx.fill(CGRect(x: 25, y: 4, width: 7, height: 16))
    }
}

// MARK: - 피리 연주 오버레이 (8초 음표 파티클)

private final class Extra17FluteWindow: NSPanel {
    var onFinish: (() -> Void)?
    private var animTimer: Timer?
    private var finishTimer: Timer?
    private var phase: TimeInterval = 0
    private var drawView: Extra17FluteDrawView?
    private var isDone = false

    init(startPos: CGPoint) {
        let size = NSSize(width: 96, height: 72)
        super.init(
            contentRect: NSRect(x: startPos.x - 48, y: startPos.y + 60, width: size.width, height: size.height),
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
        let view = Extra17FluteDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        if let animTimer = animTimer {
            RunLoop.main.add(animTimer, forMode: .common)
        }
        finishTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.finish()
        }
        RunLoop.main.add(finishTimer!, forMode: .common)
    }

    private func finish() {
        guard !isDone else { return }
        isDone = true
        animTimer?.invalidate()
        animTimer = nil
        finishTimer?.invalidate()
        finishTimer = nil
        let cb = onFinish
        onFinish = nil
        close()
        cb?()
    }

    func dismiss() {
        guard !isDone else { return }
        isDone = true
        animTimer?.invalidate()
        animTimer = nil
        finishTimer?.invalidate()
        finishTimer = nil
        onFinish = nil
        close()
    }

    override func close() {
        animTimer?.invalidate()
        animTimer = nil
        finishTimer?.invalidate()
        finishTimer = nil
        super.close()
    }
}

private final class Extra17FluteDrawView: NSView {
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 피리 (가로 대나무 막대)
        ctx.setFillColor(red: 0.72, green: 0.55, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 12, width: 60, height: 10))
        ctx.setFillColor(red: 0.45, green: 0.32, blue: 0.16, alpha: 1.0)
        for x in [30, 42, 54, 66] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 12, width: 3, height: 10))
        }
        // 떠오르는 음표 3개
        let notes = ["♪", "♫", "♪"]
        for i in 0..<3 {
            let rise = fmod(phase * 22.0 + Double(i) * 22.0, 66.0)
            let x = 24.0 + Double(i) * 22.0 + sin(phase * 3.0 + Double(i)) * 4.0
            let y = 26.0 + rise
            let s = "♪ \(notes[i])" as NSString
            _ = s
            (notes[i] as NSString).draw(
                at: NSPoint(x: x, y: y),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 16),
                    .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.3, blue: 0.9, alpha: 1.0)
                ]
            )
        }
    }
}

// MARK: - 활공 링 (하늘 링 3개, 순서대로 클릭)

private final class Extra17GlideRingWindow: NSPanel {
    let ringIndex: Int
    var onTap: ((Int) -> Void)?
    private var drawView: Extra17GlideRingDrawView?

    init(startPos: CGPoint, index: Int) {
        self.ringIndex = index
        let size = NSSize(width: 76, height: 76)
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
        let view = Extra17GlideRingDrawView(frame: NSRect(origin: .zero, size: size))
        view.index = index
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        onTap?(ringIndex)
    }

    func dismiss() {
        onTap = nil
        close()
    }
}

private final class Extra17GlideRingDrawView: NSView {
    var index: Int = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let c = bounds.width / 2.0
        // 바깥 링 (황금)
        ctx.setStrokeColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        ctx.setLineWidth(6.0)
        ctx.strokeEllipse(in: CGRect(x: c - 26, y: c - 26, width: 52, height: 52))
        // 안쪽 링 (흰색)
        ctx.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        ctx.setLineWidth(2.0)
        ctx.strokeEllipse(in: CGRect(x: c - 18, y: c - 18, width: 36, height: 36))
        // 순서 표시 점 (index+1개)
        ctx.setFillColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        for i in 0...index {
            ctx.fillEllipse(in: CGRect(x: c - 12 + CGFloat(i) * 12, y: c - 3, width: 7, height: 7))
        }
    }
}

// MARK: - 17차 이벤트 매니저

public final class EventManager {
    public static let shared = EventManager()
    private init() {}

    // 약탈자 습격 상태
    private var raidWindows: [Extra17PillagerWindow] = []
    private var raidWave: Int = 0
    private var raidActive: Bool = false
    private var raidDelayTimer: Timer?

    // 피리 상태
    private var fluteWindow: Extra17FluteWindow?

    // 활공 링 상태
    private var ringWindows: [Extra17GlideRingWindow] = []
    private var ringNext: Int = 0
    private var ringStartTime: Date?
    private var ringTimeoutTimer: Timer?

    // 멍때리기 상태
    private var chillOn: Bool = false
    private var chillTimer: Timer?
    private var chillXP: Int = 0

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🏹 약탈자 습격" }, { [weak self] in self?.startRaid() }),
            ExtraMenuEntry({ "🪈 피리 연주" }, { [weak self] in self?.startFlute() }),
            ExtraMenuEntry({ "🧑‍✈️ 활공 링" }, { [weak self] in self?.startRings() }),
            ExtraMenuEntry({ [weak self] in
                guard let self = self else { return "🧘 멍때리기" }
                let state = self.chillOn ? "ON" : "OFF"
                return "🧘 멍때리기 (\(state)・누적 \(self.chillXP)XP)"
            }, { [weak self] in self?.toggleChill() }),
            ExtraMenuEntry({ MobHeadWard.shared.wearing.map { "💀 몹 머리 벗기 (\($0.name))" }
                ?? MobHeadWard.shared.owned.map { "💀 몹 머리 쓰기 (\(($0.name)) 보유)" }
                ?? "💀 몹 머리 쓰기" }, { [weak self] in self?.runMobHead() })
        ]
    }

    // MARK: - 1. 약탈자 습격 (예감 3초 → 웨이브 1→2→3 → 영웅 보상)

    private func startRaid() {
        cleanupRaid()
        raidActive = true
        raidWave = 0
        RewardCenter.say("😱 불길한 예감... 약탈자가 몰려온다!")
        SoundAndEffectsManager.shared.play(.alert)
        raidDelayTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.raidDelayTimer?.invalidate()
            self?.raidDelayTimer = nil
            self?.spawnRaidWave(0)
        }
        RunLoop.main.add(raidDelayTimer!, forMode: .common)
    }

    private func spawnRaidWave(_ wave: Int) {
        guard raidActive else { return }
        raidWave = wave
        let counts = [1, 2, 3]
        let count = wave < counts.count ? counts[wave] : 1
        let base = RewardCenter.me()
        for k in 0..<count {
            let pos = CGPoint(x: base.x + CGFloat(k * 70) - CGFloat(count * 35) + 60, y: base.y + 30)
            let win = Extra17PillagerWindow(startPos: pos)
            win.onTap = { [weak self, weak win] in
                guard let self = self, let win = win else { return }
                self.pillagerTapped(win)
            }
            raidWindows.append(win)
            win.start()
        }
        RewardCenter.say("🏹 \(wave + 1)웨이브! 약탈자 \(count)마리! (클릭 격퇴!)")
        SoundAndEffectsManager.shared.play(.alert)
    }

    private func pillagerTapped(_ win: Extra17PillagerWindow) {
        win.dismiss()
        raidWindows.removeAll(where: { $0 === win })
        SoundAndEffectsManager.shared.play(.pop)
        if raidWindows.isEmpty {
            if raidWave < 2 {
                spawnRaidWave(raidWave + 1)
            } else {
                raidActive = false
                SoundAndEffectsManager.shared.play(.chime)
                RewardCenter.grant(xp: 10, "🎖️ 마을의 영웅! 약탈자 전멸!")
            }
        } else {
            RewardCenter.say("💥 격퇴! 남은 약탈자 \(raidWindows.count)마리!")
        }
    }

    private func cleanupRaid() {
        raidDelayTimer?.invalidate()
        raidDelayTimer = nil
        for w in raidWindows { w.dismiss() }
        raidWindows.removeAll()
        raidActive = false
    }

    // MARK: - 2. 피리 연주 (8초 자장가 → 숙면 버프 +3XP)

    private func startFlute() {
        fluteWindow?.dismiss()
        fluteWindow = nil
        RewardCenter.say("🌙 평화로운 밤... 🪈 자장가를 연주한다!")
        SoundAndEffectsManager.shared.play(.heart)
        let win = Extra17FluteWindow(startPos: RewardCenter.me())
        win.onFinish = { [weak self] in
            guard let self = self else { return }
            self.fluteWindow = nil
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: 3, "💤 쿨쿨... 숙면 버프!")
        }
        fluteWindow = win
        win.start()
    }

    // MARK: - 3. 활공 링 (순서대로 클릭, 미스 리셋, 완주 +5XP)

    private func startRings() {
        cleanupRings()
        let base = RewardCenter.me()
        let positions = [
            CGPoint(x: base.x - 120, y: base.y + 120),
            CGPoint(x: base.x + 20, y: base.y + 200),
            CGPoint(x: base.x + 150, y: base.y + 280)
        ]
        ringNext = 0
        ringStartTime = Date()
        for i in 0..<3 {
            let win = Extra17GlideRingWindow(startPos: positions[i], index: i)
            win.onTap = { [weak self] idx in self?.ringTapped(idx) }
            ringWindows.append(win)
            win.start()
        }
        RewardCenter.say("🧑‍✈️ 활공 링! 낮은 링부터 순서대로 클릭!")
        SoundAndEffectsManager.shared.play(.whoosh)
        ringTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.ringWindows.isEmpty {
                self.cleanupRings()
                RewardCenter.say("⌛ 링 챌린지 종료! 다음에 다시 도전!")
            }
        }
        RunLoop.main.add(ringTimeoutTimer!, forMode: .common)
    }

    private func ringTapped(_ idx: Int) {
        guard !ringWindows.isEmpty else { return }
        if idx == ringNext {
            if let win = ringWindows.first(where: { $0.ringIndex == idx }) {
                win.dismiss()
                ringWindows.removeAll(where: { $0 === win })
            }
            SoundAndEffectsManager.shared.play(.jump)
            ringNext += 1
            if ringNext >= 3 {
                let elapsed = ringStartTime.map { Date().timeIntervalSince($0) } ?? 0
                ringTimeoutTimer?.invalidate()
                ringTimeoutTimer = nil
                ringStartTime = nil
                SoundAndEffectsManager.shared.play(.chime)
                RewardCenter.grant(xp: 5, "🧑‍✈️ 완주! \(String(format: "%.1f", elapsed))초 통과! +5XP")
            } else {
                RewardCenter.say("⭕ 링 통과! (\(ringNext)/3)")
            }
        } else {
            SoundAndEffectsManager.shared.play(.alert)
            RewardCenter.say("💦 미스! 처음부터 다시!")
            startRings()
        }
    }

    private func cleanupRings() {
        ringTimeoutTimer?.invalidate()
        ringTimeoutTimer = nil
        for w in ringWindows { w.dismiss() }
        ringWindows.removeAll()
        ringNext = 0
        ringStartTime = nil
    }

    // MARK: - 4. 멍때리기 (칠 모드 토글, 60초 +1XP, 제목에 누적 표시)

    private func toggleChill() {
        if chillOn {
            chillTimer?.invalidate()
            chillTimer = nil
            chillOn = false
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🍵 휴식 끝! 총 \(chillXP)XP 멍때렸다!")
        } else {
            chillOn = true
            SoundAndEffectsManager.shared.play(.heart)
            RewardCenter.say("🧘 멍 때리는 중... 60초마다 +1XP")
            chillTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if !self.chillOn { return }
                self.chillXP += 1
                RewardCenter.grant(xp: 1, "🧘 멍...")
            }
            RunLoop.main.add(chillTimer!, forMode: .common)
        }
    }

    // MARK: - 5. 몹 머리 (보유 없으면 랜덤 드롭 → 쓰기/벗기 순환, 착용 중 +1XP)

    private func runMobHead() {
        let ward = MobHeadWard.shared
        if ward.owned == nil {
            let got = ward.obtainRandom()
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("💀 \(got.emoji) \(got.name) 머리 획득! 다시 선택하면 착용!")
            return
        }
        if ward.wearing == nil {
            ward.wear()
            if let w = ward.wearing {
                SoundAndEffectsManager.shared.play(.heart)
                RewardCenter.say("💀 \(w.name) 머리 착용! 크리퍼・스켈레톤・좀비는 날 못 알아봐!")
            }
            return
        }
        if let w = ward.wearing {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.grant(xp: 1, "🤫 변장 중! \(w.name)은 날 지나쳐! (머리 벗음)")
            ward.takeOff()
        }
    }
}
