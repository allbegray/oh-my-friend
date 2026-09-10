import AppKit
import CoreGraphics

// F분야 레드스톤 10종: 피스톤문·옵저버·호퍼·디스펜서·비교기·중계기·일광센서·크래프터·구리전구·스포너.
// RedstoneFManager.shared.entries()로 메뉴에 연결한다. 기존 파일 무수정, 네트워크/UserDefaults 미사용.

public final class RedstoneFManager {
    public static let shared = RedstoneFManager()
    private init() {}

    private var pistonWindow: FRedPistonDoorWindow?
    private var observerWindow: FRedObserverWindow?
    private var hopperWindow: FRedHopperWindow?
    private var hopperCount = 0
    private var dispenserWindow: FRedDispenserWindow?
    private var comparatorWindow: FRedComparatorWindow?
    private var comparatorFill = 0
    private var repeaterWindow: FRedRepeaterWindow?
    private var repeaterTicks = 2
    private var sensorWindow: FRedDaylightWindow?
    private var crafterWindow: FRedCrafterWindow?
    private var bulbWindow: FRedCopperBulbWindow?
    private var spawnerWindow: FRedTrialSpawnerWindow?
    private var spawnerWave = 0
    private var spawnerLeft = 0

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🟫 피스톤 문" }, { [weak self] in self?.spawnPistonDoor() }),
            ExtraMenuEntry({ "👀 옵저버 팜" }, { [weak self] in self?.spawnObserver() }),
            ExtraMenuEntry({ "⛏️ 호퍼 수거" }, { [weak self] in self?.spawnHopper() }),
            ExtraMenuEntry({ "🎯 디스펜서" }, { [weak self] in self?.spawnDispenser() }),
            ExtraMenuEntry({ "⚖️ 비교기" }, { [weak self] in self?.spawnComparator() }),
            ExtraMenuEntry({ "⏱️ 중계기" }, { [weak self] in self?.spawnRepeater() }),
            ExtraMenuEntry({ "☀️ 일광 센서" }, { [weak self] in self?.spawnSensor() }),
            ExtraMenuEntry({ "🛠️ 크래프터" }, { [weak self] in self?.spawnCrafter() }),
            ExtraMenuEntry({ "🟧 구리 전구" }, { [weak self] in self?.spawnBulb() }),
            ExtraMenuEntry({ "🧪 트라이얼 스포너" }, { [weak self] in self?.spawnSpawner() }),
        ]
    }

    // MARK: - 1. 피스톤 문 (2x2 + 클릭 개폐 + 커서 자동문)

    private func spawnPistonDoor() {
        if pistonWindow == nil {
            let me = RewardCenter.me()
            let w = FRedPistonDoorWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                onToggle: { [weak self] in self?.togglePistonDoor() }
            )
            pistonWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.pistonWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🟫 피스톤 문 설치! 가까이 가면 자동!")
        } else {
            togglePistonDoor()
        }
    }

    private func togglePistonDoor() {
        guard let w = pistonWindow else { return }
        w.setOpen(!w.isOpen, auto: false)
        if w.isOpen {
            SoundAndEffectsManager.shared.play(.whoosh)
            RewardCenter.say("🚪 스윽… 문 열림!")
        } else {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🚪 쿵! 문 닫힘!")
        }
    }

    // MARK: - 2. 옵저버 팜 (자체 새싹 + 성장 감지 + 자동 수확 +2XP)

    private func spawnObserver() {
        if observerWindow == nil {
            let me = RewardCenter.me()
            let w = FRedObserverWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                onMature: { [weak self] in self?.harvestObserver() },
                onTap: { [weak self] in self?.tapObserver() }
            )
            observerWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.observerWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("👀 옵저버가 새싹 감시 중…")
        } else {
            tapObserver()
        }
    }

    private func tapObserver() {
        guard let w = observerWindow else { return }
        if w.stage >= 3 {
            harvestObserver()
        } else {
            w.growOne()
            SoundAndEffectsManager.shared.play(.splash)
            RewardCenter.say("🌱 쑥쑥… \(w.stage)/3")
        }
    }

    private func harvestObserver() {
        guard let w = observerWindow else { return }
        w.reset()
        SoundAndEffectsManager.shared.play(.chime)
        RewardCenter.grant(xp: 2, "👀 감지! 자동 수확 +2XP!")
    }

    // MARK: - 3. 호퍼 수거 (클릭 흡수 + 카운터)

    private func spawnHopper() {
        if hopperWindow == nil {
            let me = RewardCenter.me()
            let w = FRedHopperWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                count: hopperCount,
                onSuck: { [weak self] in self?.suckHopper() }
            )
            hopperWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.hopperWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("⛏️ 호퍼 설치! 클릭하면 흡수!")
        } else {
            suckHopper()
        }
    }

    private func suckHopper() {
        hopperCount += 1
        hopperWindow?.count = hopperCount
        hopperWindow?.pulse()
        SoundAndEffectsManager.shared.play(.pop)
        if hopperCount % 5 == 0 {
            RewardCenter.grant(xp: 1, "⛏️ \(hopperCount)개 수거!")
        } else {
            RewardCenter.say("🌀 쏙! (\(hopperCount))")
        }
    }

    // MARK: - 4. 디스펜서 (화살 5발 + 클릭 발사 + 재장전)

    private func spawnDispenser() {
        if dispenserWindow == nil {
            let me = RewardCenter.me()
            let w = FRedDispenserWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                onFire: { [weak self] in self?.fireDispenser() }
            )
            dispenserWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.dispenserWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🎯 디스펜서 장전! (➡️×5)")
        } else {
            fireDispenser()
        }
    }

    private func fireDispenser() {
        guard let w = dispenserWindow else { return }
        if w.arrows > 0 {
            w.shoot()
            SoundAndEffectsManager.shared.play(.whoosh)
            RewardCenter.say("➡️ 퓽! (\(w.arrows)발 남음)")
        } else {
            w.reload()
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.say("🎯 딸깍… 재장전 완료! (×5)")
        }
    }

    // MARK: - 5. 비교기 (자체 상자 + 게이지 + 가득 차면 종 +2XP)

    private func spawnComparator() {
        if comparatorWindow == nil {
            let me = RewardCenter.me()
            let w = FRedComparatorWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                fill: comparatorFill,
                onFill: { [weak self] in self?.fillComparator() }
            )
            comparatorWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.comparatorWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("⚖️ 비교기 상자! 클릭으로 채우기!")
        } else {
            fillComparator()
        }
    }

    private func fillComparator() {
        comparatorFill += 1
        if comparatorFill >= 8 {
            comparatorFill = 0
            comparatorWindow?.fill = 0
            comparatorWindow?.pulse()
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: 2, "🔔 가득 참! +2XP!")
        } else {
            comparatorWindow?.fill = comparatorFill
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("📦 \(comparatorFill)/8")
        }
    }

    // MARK: - 6. 중계기 (1~4틱 설정 + 지연 폭죽 + 타이밍 +3XP)

    private func spawnRepeater() {
        let alert = NSAlert()
        alert.messageText = "⏱️ 중계기 지연"
        alert.informativeText = "신호 지연 틱을 고르세요. 불 켜진 순간 클릭하면 타이밍 보너스!"
        alert.addButton(withTitle: "1틱")
        alert.addButton(withTitle: "2틱")
        alert.addButton(withTitle: "3틱")
        alert.addButton(withTitle: "4틱")
        let resp = alert.runModal()
        switch resp {
        case .alertFirstButtonReturn: repeaterTicks = 1
        case .alertSecondButtonReturn: repeaterTicks = 2
        case .alertThirdButtonReturn: repeaterTicks = 3
        default: repeaterTicks = 4
        }
        repeaterWindow?.close()
        let me = RewardCenter.me()
        let ticks = repeaterTicks
        let w = FRedRepeaterWindow(
            floorPos: CGPoint(x: me.x, y: me.y),
            ticks: ticks,
            onTap: { [weak self] in self?.tapRepeater() }
        )
        repeaterWindow = w
        w.place()
        w.onClosed = { [weak self] in self?.repeaterWindow = nil }
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("⏱️ \(ticks)틱 지연… 곧 펑!")
    }

    private func tapRepeater() {
        guard let w = repeaterWindow else { return }
        if w.isLit {
            w.consume()
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: 3, "🎆 타이밍 적중! +3XP!")
        } else {
            SoundAndEffectsManager.shared.play(.splash)
            RewardCenter.say("⏱️ 아직… 불 켜지면 클릭!")
        }
    }

    // MARK: - 7. 일광 센서 (낮/밤 자동 + 밤 횃불 + 낮 커튼)

    private func spawnSensor() {
        sensorWindow?.close()
        let me = RewardCenter.me()
        let w = FRedDaylightWindow(floorPos: CGPoint(x: me.x, y: me.y))
        sensorWindow = w
        w.place()
        w.onClosed = { [weak self] in self?.sensorWindow = nil }
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say(w.isDay ? "☀️ 낮! 커튼 쨍!" : "🌙 밤! 횃불 활활!")
    }

    // MARK: - 8. 크래프터 (자체 재료 3종 + 조합 → 빵·케이크 +3XP)

    private func spawnCrafter() {
        if crafterWindow == nil {
            let me = RewardCenter.me()
            let w = FRedCrafterWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                onCraft: { [weak self] in self?.craftCombo() }
            )
            crafterWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.crafterWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🛠️ 재료 3개를 눌러 담아요!")
        } else {
            craftCombo()
        }
    }

    private func craftCombo() {
        guard let w = crafterWindow else { return }
        if w.craftIfReady() {
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: 3, w.lastProduct)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🧺 재료 \(w.insertedCount)/3")
        }
    }

    // MARK: - 9. 구리 전구 (산화 4단계 + 밝기 + 왁스 연출)

    private func spawnBulb() {
        if bulbWindow == nil {
            let me = RewardCenter.me()
            let w = FRedCopperBulbWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                onTap: { [weak self] in self?.tapBulb() }
            )
            bulbWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.bulbWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🟧 구리 전구! 클릭할수록 산화!")
        } else {
            tapBulb()
        }
    }

    private func tapBulb() {
        guard let w = bulbWindow else { return }
        if w.waxed {
            SoundAndEffectsManager.shared.play(.splash)
            RewardCenter.say("🍯 왁스 코팅됨! 반짝 유지!")
            return
        }
        w.advance()
        SoundAndEffectsManager.shared.play(.pop)
        if w.stage >= 3 {
            w.waxed = true
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.say("🍯 완전 산화 → 왁스 코팅! (연출)")
        } else {
            RewardCenter.say("🟧 산화 \(w.stage)/3 · 밝기 \(w.brightnessText)")
        }
    }

    // MARK: - 10. 트라이얼 스포너 (웨이브 1→2→3 + 격퇴 +6XP)

    private func spawnSpawner() {
        spawnerWindow?.close()
        spawnerWave = 1
        spawnerLeft = 1
        let me = RewardCenter.me()
        let w = FRedTrialSpawnerWindow(
            floorPos: CGPoint(x: me.x, y: me.y),
            wave: spawnerWave,
            left: spawnerLeft,
            onHit: { [weak self] in self?.hitSpawner() }
        )
        spawnerWindow = w
        w.place()
        w.onClosed = { [weak self] in self?.spawnerWindow = nil }
        SoundAndEffectsManager.shared.play(.portal)
        RewardCenter.say("🧪 웨이브 1! 몹 1마리!")
    }

    private func hitSpawner() {
        guard let w = spawnerWindow else { return }
        spawnerLeft -= 1
        SoundAndEffectsManager.shared.play(.jump)
        if spawnerLeft > 0 {
            w.setWave(spawnerWave, left: spawnerLeft)
            RewardCenter.say("💥 명중! \(spawnerLeft)마리 남음!")
            return
        }
        if spawnerWave >= 3 {
            spawnerWindow?.close()
            spawnerWindow = nil
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: 6, "🏆 트라이얼 제패! +6XP!")
        } else {
            spawnerWave += 1
            spawnerLeft = spawnerWave + (spawnerWave == 3 ? 0 : 0)
            if spawnerWave == 2 { spawnerLeft = 2 }
            if spawnerWave == 3 { spawnerLeft = 3 }
            w.setWave(spawnerWave, left: spawnerLeft)
            SoundAndEffectsManager.shared.play(.portal)
            RewardCenter.say("🧪 웨이브 \(spawnerWave)! 몹 \(spawnerLeft)마리!")
        }
    }
}

// MARK: - 1. 피스톤 문 패널

private final class FRedPistonDoorWindow: NSPanel {
    private(set) var isOpen = false
    private var slide: CGFloat = 0
    private var autoMode = true
    var onClosed: (() -> Void)?
    private let onToggle: () -> Void
    private var drawView: FRedPistonDoorDrawView?
    private var timer: Timer?

    init(floorPos: CGPoint, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        let size = NSSize(width: 120, height: 120)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedPistonDoorDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.tickAuto()
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func setOpen(_ open: Bool, auto: Bool) {
        isOpen = open
        if !auto {
            // 수동 토글은 그대로 두되 자동 감시는 유지한다.
        }
        drawView?.isOpen = open
        drawView?.slide = open ? 1.0 : 0.0
        drawView?.needsDisplay = true
    }

    private func tickAuto() {
        guard autoMode else { return }
        let mouse = NSEvent.mouseLocation
        let c = NSPoint(x: frame.midX, y: frame.midY)
        let d = hypot(mouse.x - c.x, mouse.y - c.y)
        let shouldOpen = d < 130
        if shouldOpen != isOpen {
            setOpen(shouldOpen, auto: true)
            drawView?.needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            autoMode.toggle()
            RewardCenter.say(autoMode ? "🚪 자동문 ON!" : "🚪 수동문…")
            return
        }
        onToggle()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedPistonDoorDrawView: NSView {
    var isOpen = false
    var slide: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 피스톤 몸통 좌우
        ctx.setFillColor(red: 0.55, green: 0.45, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 30, width: 12, height: 60))
        ctx.fill(CGRect(x: w - 14, y: 30, width: 12, height: 60))
        ctx.setFillColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 52, width: 10, height: 8))
        ctx.fill(CGRect(x: w - 24, y: 52, width: 10, height: 8))
        // 2x2 블록문 (열리면 좌우로 밀림)
        let off = slide * 26.0
        let bw: CGFloat = 22
        let bh: CGFloat = 26
        let cx = w / 2
        // 왼쪽 2칸
        ctx.setFillColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: cx - bw - off, y: 34, width: bw, height: bh))
        ctx.fill(CGRect(x: cx - bw - off, y: 34 + bh, width: bw, height: bh))
        // 오른쪽 2칸
        ctx.fill(CGRect(x: cx + 0 + off, y: 34, width: bw, height: bh))
        ctx.fill(CGRect(x: cx + 0 + off, y: 34 + bh, width: bw, height: bh))
        ctx.setFillColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: cx - bw - off, y: 34 + bh * 2 - 3, width: bw * 2 + off * 2, height: 3))
        let label = NSAttributedString(
            string: isOpen ? "🚪 열림" : "🟫 닫힘",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 24, y: 96))
    }
}

// MARK: - 2. 옵저버 팜 패널

private final class FRedObserverWindow: NSPanel {
    private(set) var stage = 0
    var onClosed: (() -> Void)?
    private let onMature: () -> Void
    private let onTap: () -> Void
    private var drawView: FRedObserverDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, onMature: @escaping () -> Void, onTap: @escaping () -> Void) {
        self.onMature = onMature
        self.onTap = onTap
        let size = NSSize(width: 96, height: 104)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedObserverDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if self.stage < 3 {
                self.stage += 1
                self.drawView?.stage = self.stage
                self.drawView?.needsDisplay = true
                if self.stage >= 3 { self.onMature() }
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func growOne() {
        stage = min(3, stage + 1)
        drawView?.stage = stage
        drawView?.needsDisplay = true
        if stage >= 3 { onMature() }
    }

    func reset() {
        stage = 0
        drawView?.stage = 0
        drawView?.flash = 1.0
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onTap() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedObserverDrawView: NSView {
    var stage = 0
    var flash: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 옵저버 얼굴
        ctx.setFillColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 22, y: 52, width: 44, height: 36))
        ctx.setFillColor(red: 0.9, green: 0.25, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2 - 8, y: 64, width: 16, height: 16))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2 - 4, y: 68, width: 8, height: 8))
        // 밭 + 새싹
        ctx.setFillColor(red: 0.4, green: 0.28, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 6, width: w - 20, height: 34))
        ctx.setFillColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        for i in 0..<3 {
            ctx.fill(CGRect(x: 16 + CGFloat(i) * 24, y: 24, width: 16, height: 3))
        }
        let h = CGFloat(6 + stage * 8)
        ctx.setFillColor(red: 0.25, green: 0.65, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 2, y: 30, width: 4, height: h))
        if stage >= 2 {
            ctx.fillEllipse(in: CGRect(x: w / 2 - 10, y: 30 + h - 6, width: 20, height: 10))
        }
        if stage >= 3 {
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: w / 2 - 5, y: 30 + h - 2, width: 10, height: 8))
        }
        if flash > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 0.4, alpha: flash * 0.4)
            ctx.fill(CGRect(x: 10, y: 6, width: w - 20, height: 34))
            flash = max(0, flash - 0.3)
            needsDisplay = true
        }
        let label = NSAttributedString(
            string: stage >= 3 ? "👀 감지!" : "🌱 \(stage)/3",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 20, y: 88))
    }
}

// MARK: - 3. 호퍼 패널

private final class FRedHopperWindow: NSPanel {
    var count = 0 { didSet { drawView?.count = count; drawView?.needsDisplay = true } }
    var onClosed: (() -> Void)?
    private let onSuck: () -> Void
    private var drawView: FRedHopperDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private let emojis = ["🌾", "🥔", "🍉", "🥕", "🍎"]

    init(floorPos: CGPoint, count: Int, onSuck: @escaping () -> Void) {
        self.count = count
        self.onSuck = onSuck
        let size = NSSize(width: 96, height: 96)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedHopperDrawView(frame: NSRect(origin: .zero, size: size))
        v.count = count
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func pulse() {
        drawView?.pulsePhase = 1.0
        if let v = drawView {
            v.lastEmoji = emojis[count % emojis.count]
        }
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onSuck() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedHopperDrawView: NSView {
    var count = 0
    var pulsePhase: CGFloat = 0
    var lastEmoji = "🌾"
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let s = 1.0 + pulsePhase * 0.2
        // 깔때기
        ctx.setFillColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 26 * s, y: 44, width: 52 * s, height: 18))
        ctx.fill(CGRect(x: w / 2 - 8, y: 20, width: 16, height: 26))
        ctx.setFillColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 20 * s, y: 56, width: 40 * s, height: 8))
        let e = NSAttributedString(
            string: lastEmoji,
            attributes: [.font: NSFont.systemFont(ofSize: 18 * s), .foregroundColor: NSColor.labelColor]
        )
        e.draw(at: NSPoint(x: w / 2 - 10 * s, y: 62 - pulsePhase * 14))
        let label = NSAttributedString(
            string: "⛏️ \(count)개",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 22, y: 4))
        if pulsePhase > 0 { pulsePhase = max(0, pulsePhase - 0.25); needsDisplay = true }
    }
}

// MARK: - 4. 디스펜서 패널

private final class FRedDispenserWindow: NSPanel {
    private(set) var arrows = 5
    var onClosed: (() -> Void)?
    private let onFire: () -> Void
    private var drawView: FRedDispenserDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, onFire: @escaping () -> Void) {
        self.onFire = onFire
        let size = NSSize(width: 120, height: 88)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedDispenserDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func shoot() {
        arrows = max(0, arrows - 1)
        drawView?.arrows = arrows
        drawView?.shotPhase = 1.0
        drawView?.needsDisplay = true
    }

    func reload() {
        arrows = 5
        drawView?.arrows = arrows
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onFire() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedDispenserDrawView: NSView {
    var arrows = 5
    var shotPhase: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 본체
        ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 18, width: 56, height: 56))
        ctx.setFillColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 40, width: 20, height: 12))
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 32, y: 42, width: 8, height: 8))
        // 장전 화살
        var shown = ""
        for _ in 0..<arrows { shown += "➡️" }
        if arrows <= 0 { shown = "빈통" }
        let label = NSAttributedString(
            string: shown,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: 10, y: 2))
        // 발사 미니 화살
        if shotPhase > 0 {
            let x = 64 + (1.0 - shotPhase) * 44
            ctx.setStrokeColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            ctx.setLineWidth(2.0)
            ctx.move(to: CGPoint(x: x, y: 46))
            ctx.addLine(to: CGPoint(x: x + 14, y: 46))
            ctx.strokePath()
            shotPhase = max(0, shotPhase - 0.2)
            needsDisplay = true
        }
        let title = NSAttributedString(
            string: "🎯 \(arrows)/5",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        title.draw(at: NSPoint(x: w - 52, y: 72))
    }
}

// MARK: - 5. 비교기 패널

private final class FRedComparatorWindow: NSPanel {
    var fill = 0 { didSet { drawView?.fill = fill; drawView?.needsDisplay = true } }
    var onClosed: (() -> Void)?
    private let onFill: () -> Void
    private var drawView: FRedComparatorDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, fill: Int, onFill: @escaping () -> Void) {
        self.fill = fill
        self.onFill = onFill
        let size = NSSize(width: 120, height: 96)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedComparatorDrawView(frame: NSRect(origin: .zero, size: size))
        v.fill = fill
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func pulse() {
        drawView?.pulsePhase = 1.0
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onFill() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedComparatorDrawView: NSView {
    var fill = 0
    var pulsePhase: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 자체 상자
        ctx.setFillColor(red: 0.55, green: 0.4, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 8, width: 56, height: 40))
        ctx.setFillColor(red: 0.4, green: 0.28, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 40, width: 56, height: 8))
        // 가득참 게이지
        ctx.setFillColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 72, y: 8, width: 14, height: 64))
        let frac = CGFloat(fill) / 8.0
        ctx.setFillColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 72, y: 8, width: 14, height: 64 * frac))
        // 비교기 본체 + 횃불
        ctx.setFillColor(red: 0.7, green: 0.68, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 56, width: 56, height: 14))
        ctx.setFillColor(red: fill >= 8 ? 1.0 : 0.45, green: 0.3, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 92, y: 56, width: 10, height: 14))
        if pulsePhase > 0 {
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.3, alpha: pulsePhase * 0.5)
            ctx.fillEllipse(in: CGRect(x: 70, y: 40, width: 40, height: 40))
            pulsePhase = max(0, pulsePhase - 0.2)
            needsDisplay = true
        }
        let label = NSAttributedString(
            string: fill >= 8 ? "🔔 가득!" : "⚖️ \(fill)/8",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: 8, y: 76))
        _ = w
    }
}

// MARK: - 6. 중계기 패널

private final class FRedRepeaterWindow: NSPanel {
    private(set) var ticks: Int
    private(set) var isLit = false
    var onClosed: (() -> Void)?
    private let onTap: () -> Void
    private var drawView: FRedRepeaterDrawView?
    private var fireTimer: Timer?
    private var lifeTimer: Timer?
    private var life: TimeInterval = 0

    init(floorPos: CGPoint, ticks: Int, onTap: @escaping () -> Void) {
        self.ticks = ticks
        self.onTap = onTap
        let size = NSSize(width: 120, height: 80)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedRepeaterDrawView(frame: NSRect(origin: .zero, size: size))
        v.ticks = ticks
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        fireTimer?.invalidate()
        lifeTimer?.invalidate()
        life = 0
        let delay = Double(ticks) * 0.5
        fireTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.lightUp()
        }
        lifeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.life += 1.0
            if self.life >= 30 {
                t.invalidate()
                self.lifeTimer = nil
                self.close()
            }
        }
        if let t = fireTimer { RunLoop.main.add(t, forMode: .common) }
        if let t = lifeTimer { RunLoop.main.add(t, forMode: .common) }
    }

    private func lightUp() {
        isLit = true
        drawView?.isLit = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.whoosh)
        RewardCenter.say("🎆 펑! 지금 클릭!")
        fireTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.isLit {
                self.isLit = false
                self.drawView?.isLit = false
                self.drawView?.needsDisplay = true
            }
        }
        if let t = fireTimer { RunLoop.main.add(t, forMode: .common) }
    }

    func consume() {
        isLit = false
        drawView?.isLit = false
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onTap() }

    override func close() {
        fireTimer?.invalidate()
        fireTimer = nil
        lifeTimer?.invalidate()
        lifeTimer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedRepeaterDrawView: NSView {
    var ticks = 2
    var isLit = false
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        if isLit {
            ctx.setFillColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.35)
            ctx.fillEllipse(in: CGRect(x: 4, y: 4, width: w - 8, height: 60))
        }
        ctx.setFillColor(red: 0.6, green: 0.58, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 14, width: w - 28, height: 28))
        ctx.setFillColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1.0)
        for i in 0..<4 {
            let on = i < ticks
            ctx.setFillColor(red: on ? 1.0 : 0.4, green: on ? 0.35 : 0.38, blue: on ? 0.15 : 0.36, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 24 + CGFloat(i) * 20, y: 24, width: 12, height: 12))
        }
        let label = NSAttributedString(
            string: isLit ? "🎆 펑!" : "⏱️ \(ticks)틱",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 26, y: 50))
    }
}

// MARK: - 7. 일광 센서 패널

private final class FRedDaylightWindow: NSPanel {
    private(set) var isDay = true
    var onClosed: (() -> Void)?
    private var drawView: FRedDaylightDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint) {
        let size = NSSize(width: 96, height: 96)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isDay = FRedDaylightWindow.dayNow()
        let v = FRedDaylightDrawView(frame: NSRect(origin: .zero, size: size))
        v.isDay = isDay
        drawView = v
        contentView = v
    }

    static func dayNow() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 6 && h < 18
    }

    func place() {
        orderFrontRegardless()
        refresh()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
        // 60초 뒤 자동 정리
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.close()
        }
    }

    private func refresh() {
        let d = FRedDaylightWindow.dayNow()
        if d != isDay {
            isDay = d
            drawView?.isDay = d
            drawView?.needsDisplay = true
            if d {
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.say("☀️ 낮! 커튼 쨍!")
            } else {
                SoundAndEffectsManager.shared.play(.chime)
                RewardCenter.say("🌙 밤! 횃불 활활!")
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        refresh()
        RewardCenter.say(isDay ? "☀️ 한낮 감지!" : "🌙 한밤 감지!")
        SoundAndEffectsManager.shared.play(.pop)
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedDaylightDrawView: NSView {
    var isDay = true
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 센서 본체
        ctx.setFillColor(red: 0.5, green: 0.42, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 22, y: 30, width: 44, height: 20))
        ctx.setFillColor(red: isDay ? 0.55 : 0.15, green: isDay ? 0.75 : 0.2, blue: isDay ? 0.95 : 0.45, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 18, y: 34, width: 36, height: 12))
        if isDay {
            // 낮 커튼
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.9)
            ctx.fill(CGRect(x: w / 2 - 22, y: 52, width: 10, height: 26))
            ctx.fill(CGRect(x: w / 2 + 12, y: 52, width: 10, height: 26))
            let sun = NSAttributedString(
                string: "☀️",
                attributes: [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor.labelColor]
            )
            sun.draw(at: NSPoint(x: w / 2 - 12, y: 56))
        } else {
            // 밤 횃불
            ctx.setFillColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1.0)
            ctx.fill(CGRect(x: w / 2 - 3, y: 52, width: 6, height: 18))
            ctx.setFillColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: w / 2 - 8, y: 66, width: 16, height: 16))
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: w / 2 - 4, y: 70, width: 8, height: 8))
        }
        let label = NSAttributedString(
            string: isDay ? "☀️ 낮" : "🌙 밤",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 16, y: 10))
    }
}

// MARK: - 8. 크래프터 패널 (자체 재료 3종 버튼 + 조합)

private final class FRedCrafterWindow: NSPanel {
    private(set) var inserted = [Bool](repeating: false, count: 3)
    private(set) var lastProduct = "🍞 빵 완성!"
    var insertedCount: Int { inserted.filter { $0 }.count }
    var onClosed: (() -> Void)?
    private let onCraft: () -> Void
    private var drawView: FRedCrafterDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private var craftIndex = 0

    init(floorPos: CGPoint, onCraft: @escaping () -> Void) {
        self.onCraft = onCraft
        let size = NSSize(width: 160, height: 110)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedCrafterDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    @discardableResult
    func craftIfReady() -> Bool {
        if insertedCount < 3 {
            // 다음 빈 칸에 재료 투입
            if let idx = inserted.firstIndex(of: false) {
                inserted[idx] = true
                drawView?.inserted = inserted
                drawView?.needsDisplay = true
            }
            return false
        }
        craftIndex += 1
        lastProduct = craftIndex % 2 == 0 ? "🍰 케이크 완성!" : "🍞 빵 완성!"
        inserted = [Bool](repeating: false, count: 3)
        drawView?.inserted = inserted
        drawView?.flash = 1.0
        drawView?.product = lastProduct
        drawView?.needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        let p = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
        // 재료 버튼 3칸 히트 (y 20~60, x 구간)
        if p.y >= 20 && p.y <= 62 {
            let idx: Int? = p.x < 55 ? 0 : (p.x < 105 ? 1 : 2)
            if let i = idx, !inserted[i] {
                inserted[i] = true
                drawView?.inserted = inserted
                drawView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.say("🧺 재료 \(insertedCount)/3")
                if insertedCount >= 3 {
                    // 다음 클릭에서 조합되도록 안내
                    RewardCenter.say("🛠️ 한 번 더 클릭! 조합!")
                }
                return
            }
        }
        onCraft()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedCrafterDrawView: NSView {
    var inserted = [Bool](repeating: false, count: 3)
    var flash: CGFloat = 0
    var product = ""
    private let names = ["🌾 밀", "🥚 달걀", "🍬 설탕"]
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 본체
        ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: bounds.width - 8, height: bounds.height - 8))
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: bounds.width - 8, height: 6))
        for i in 0..<3 {
            let x = 10 + CGFloat(i) * 50
            let on = i < inserted.count && inserted[i]
            ctx.setFillColor(red: on ? 0.3 : 0.75, green: on ? 0.7 : 0.73, blue: on ? 0.3 : 0.7, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: 20, width: 44, height: 42))
            let n = NSAttributedString(
                string: names[i],
                attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.labelColor]
            )
            n.draw(at: NSPoint(x: x + 4, y: 30))
        }
        if flash > 0 {
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.4, alpha: flash * 0.45)
            ctx.fill(CGRect(x: 4, y: 4, width: bounds.width - 8, height: bounds.height - 8))
            flash = max(0, flash - 0.25)
            needsDisplay = true
        }
        let title = NSAttributedString(
            string: product.isEmpty ? "🛠️ 크래프터" : product,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        title.draw(at: NSPoint(x: 12, y: bounds.height - 20))
    }
}

// MARK: - 9. 구리 전구 패널

private final class FRedCopperBulbWindow: NSPanel {
    private(set) var stage = 0
    var waxed = false
    var brightnessText: String {
        switch stage {
        case 0: return "밝음"
        case 1: return "보통"
        case 2: return "은은"
        default: return "희미"
        }
    }
    var onClosed: (() -> Void)?
    private let onTap: () -> Void
    private var drawView: FRedCopperBulbDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, onTap: @escaping () -> Void) {
        self.onTap = onTap
        let size = NSSize(width: 88, height: 104)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedCopperBulbDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func advance() {
        stage = min(3, stage + 1)
        drawView?.stage = stage
        drawView?.waxed = waxed
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onTap() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedCopperBulbDrawView: NSView {
    var stage = 0
    var waxed = false
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 산화 색 (주황 → 초록)
        let t = CGFloat(stage) / 3.0
        let r = 0.85 - t * 0.45
        let g = 0.55 + t * 0.15
        let b = 0.25 + t * 0.30
        let glow = 1.0 - t * 0.55
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.4, alpha: glow * 0.35)
        ctx.fillEllipse(in: CGRect(x: 4, y: 20, width: w - 8, height: 64))
        ctx.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 16, y: 30, width: 32, height: 32))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25 + glow * 0.6)
        ctx.fill(CGRect(x: w / 2 - 16, y: 50, width: 32, height: 5))
        // 소켓
        ctx.setFillColor(red: 0.4, green: 0.38, blue: 0.36, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 10, y: 18, width: 20, height: 12))
        if waxed {
            let wax = NSAttributedString(
                string: "🍯왁스",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
            )
            wax.draw(at: NSPoint(x: w / 2 - 20, y: 66))
        }
        let label = NSAttributedString(
            string: "🟧 \(stage)/3",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 18, y: 2))
    }
}

// MARK: - 10. 트라이얼 스포너 패널

private final class FRedTrialSpawnerWindow: NSPanel {
    private(set) var wave = 1
    private(set) var left = 1
    var onClosed: (() -> Void)?
    private let onHit: () -> Void
    private var drawView: FRedTrialSpawnerDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, wave: Int, left: Int, onHit: @escaping () -> Void) {
        self.wave = wave
        self.left = left
        self.onHit = onHit
        let size = NSSize(width: 140, height: 130)
        super.init(
            contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = FRedTrialSpawnerDrawView(frame: NSRect(origin: .zero, size: size))
        v.wave = wave
        v.left = left
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0
            self.drawView?.spin += 0.3
            self.drawView?.needsDisplay = true
            if self.elapsed >= 120 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    func setWave(_ wave: Int, left: Int) {
        self.wave = wave
        self.left = left
        drawView?.wave = wave
        drawView?.left = left
        drawView?.hitFlash = 1.0
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onHit() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class FRedTrialSpawnerDrawView: NSView {
    var wave = 1
    var left = 1
    var spin: CGFloat = 0
    var hitFlash: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 스포너 케이지
        ctx.setFillColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.9)
        ctx.fill(CGRect(x: w / 2 - 34, y: 34, width: 68, height: 60))
        ctx.setStrokeColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.stroke(CGRect(x: w / 2 - 34, y: 34, width: 68, height: 60))
        // 회전 불꽃 (연출)
        let cx = w / 2 + cos(spin) * 10
        ctx.setFillColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: cx - 5, y: 58, width: 10, height: 10))
        if hitFlash > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: hitFlash * 0.4)
            ctx.fill(CGRect(x: w / 2 - 34, y: 34, width: 68, height: 60))
            hitFlash = max(0, hitFlash - 0.3)
            needsDisplay = true
        }
        // 웨이브 몹
        var mobs = ""
        for _ in 0..<max(0, left) { mobs += "👾" }
        let mobLabel = NSAttributedString(
            string: mobs,
            attributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.labelColor]
        )
        mobLabel.draw(at: NSPoint(x: w / 2 - CGFloat(max(1, left)) * 11, y: 8))
        let title = NSAttributedString(
            string: "🧪 W\(wave)",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]
        )
        title.draw(at: NSPoint(x: w / 2 - 20, y: 100))
    }
}
