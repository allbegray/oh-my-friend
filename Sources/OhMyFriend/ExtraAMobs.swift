import AppKit
import CoreGraphics
import Foundation

// A분야 몹 10종: 워든·알레이·스니퍼·철골렘·스트레이·허스크·보고드·크리킹·엔더마이트·해골마 + MobsAManager.
// MobsAManager.shared.entries()로 중앙 메뉴에 연결한다. 스폰/해제 토글.

public final class MobsAManager {
    public static let shared = MobsAManager()

    private var warden: AWardenWindow?
    private var wardenDim: AWardenDimOverlay?
    private let allaySlot = ToggleSlot<AAllayWindow>()
    private let snifferSlot = ToggleSlot<ASnifferWindow>()
    private let golemSlot = ToggleSlot<AIronGolemWindow>()
    private var stray: AStrayWindow?
    private var strayArrow: AStrayArrowWindow?
    private var husk: AHuskWindow?
    private var bogged: ABoggedWindow?
    private var creaking: ACreakingWindow?
    private var endermite: AEndermiteWindow?
    private var horseTrap: ASkeletonHorseTrapWindow?
    private var horseFlash: ATrapFlashOverlay?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🦯 워든" }, { [weak self] in self?.toggleWarden() }),
            ExtraMenuEntry({ "🧚 알레이" }, { [weak self] in self?.toggleAllay() }),
            ExtraMenuEntry({ "🦕 스니퍼" }, { [weak self] in self?.toggleSniffer() }),
            ExtraMenuEntry({ "🛡️ 철골렘" }, { [weak self] in self?.toggleGolem() }),
            ExtraMenuEntry({ "❄️ 스트레이" }, { [weak self] in self?.toggleStray() }),
            ExtraMenuEntry({ "🏜️ 허스크" }, { [weak self] in self?.toggleHusk() }),
            ExtraMenuEntry({ "🐸 보고드" }, { [weak self] in self?.toggleBogged() }),
            ExtraMenuEntry({ "🌲 크리킹" }, { [weak self] in self?.toggleCreaking() }),
            ExtraMenuEntry({ "🟪 엔더마이트" }, { [weak self] in self?.toggleEndermite() }),
            ExtraMenuEntry({ "⚡ 해골마 트랩" }, { [weak self] in self?.toggleHorseTrap() }),
        ]
    }

    private func spawnPos(dx: CGFloat) -> CGPoint {
        let me = RewardCenter.me()
        if me == .zero {
            if let screen = NSScreen.main {
                let f = screen.frame
                return CGPoint(x: f.midX + dx, y: f.minY + 140)
            }
            return CGPoint(x: 400 + dx, y: 200)
        }
        return CGPoint(x: me.x + dx, y: me.y)
    }

    // MARK: - 워든
    public func toggleWarden() {
        if let w = warden, w.isVisible {
            w.close(); warden = nil
            wardenDim?.close(); wardenDim = nil
            return
        }
        warden = nil; wardenDim?.close(); wardenDim = nil
        let pos = spawnPos(dx: -80)
        let dim = AWardenDimOverlay(center: pos)
        wardenDim = dim
        dim.show()
        let w = AWardenWindow(startPos: pos) { [weak self] tapped in
            self?.handleWardenTap(tapped)
        }
        w.onDefeated = { [weak self] in
            self?.wardenDim?.close(); self?.wardenDim = nil
            self?.warden = nil
        }
        warden = w
        w.start()
    }

    private func handleWardenTap(_ w: AWardenWindow) {
        if w.hit() {
            RewardCenter.grant(xp: 5, "🦯 워든 격퇴!")
            SoundAndEffectsManager.shared.play(.explode)
            w.close()
            warden = nil
            wardenDim?.close(); wardenDim = nil
        } else {
            RewardCenter.say("🦯 쿵... (\(w.hits)/3)")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }

    // MARK: - 알레이
    public func toggleAllay() {
        let pos = spawnPos(dx: 60)
        allaySlot.toggle(make: {
            AAllayWindow(startPos: pos) { [weak self] tapped in
                self?.handleAllayTap(tapped)
            }
        }, start: { $0.start() })
    }

    private func handleAllayTap(_ w: AAllayWindow) {
        w.dance()
        RewardCenter.grant(xp: 2, "🧚 알레이가 춤춘다!")
        SoundAndEffectsManager.shared.play(.heart)
    }

    // MARK: - 스니퍼
    public func toggleSniffer() {
        let pos = spawnPos(dx: -60)
        snifferSlot.toggle(make: {
            ASnifferWindow(startPos: pos) { [weak self] tapped in
                self?.handleSnifferTap(tapped)
            }
        }, start: { $0.start() })
    }

    private func handleSnifferTap(_ w: ASnifferWindow) {
        if w.harvest() {
            RewardCenter.grant(xp: 3, "🌱 고대 씨앗!")
            SoundAndEffectsManager.shared.play(.pop)
        } else {
            RewardCenter.say("🦕 킁킁 파는 중...")
            SoundAndEffectsManager.shared.play(.splash)
        }
    }

    // MARK: - 철골렘
    public func toggleGolem() {
        let pos = spawnPos(dx: 80)
        golemSlot.toggle(make: {
            AIronGolemWindow(startPos: pos) { [weak self] tapped in
                self?.handleGolemTap(tapped)
            }
        }, start: { $0.start() })
    }

    private func handleGolemTap(_ w: AIronGolemWindow) {
        w.punch()
        RewardCenter.grant(xp: 2, "🌹 장미 선물!")
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - 스트레이
    public func toggleStray() {
        if let w = stray, w.isVisible {
            w.close(); stray = nil
            strayArrow?.close(); strayArrow = nil
            return
        }
        stray = nil; strayArrow?.close(); strayArrow = nil
        let w = AStrayWindow(startPos: spawnPos(dx: -100)) { [weak self] tapped in
            self?.handleStrayTap(tapped)
        }
        w.onFire = { [weak self] from in
            self?.fireSlowArrow(from: from)
        }
        stray = w
        w.start()
    }

    private func fireSlowArrow(from: CGPoint) {
        strayArrow?.close()
        let a = AStrayArrowWindow(startPos: from) { [weak self] in
            self?.stray?.applySlow()
            RewardCenter.say("🐌 슬로우!")
            SoundAndEffectsManager.shared.play(.whoosh)
            self?.strayArrow?.close()
            self?.strayArrow = nil
        }
        strayArrow = a
        a.start()
        SoundAndEffectsManager.shared.play(.whoosh)
    }

    private func handleStrayTap(_ w: AStrayWindow) {
        if w.hit() {
            RewardCenter.grant(xp: 3, "❄️ 스트레이 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); stray = nil
            strayArrow?.close(); strayArrow = nil
        } else {
            RewardCenter.say("❄️ 슬로우 화살! (\(w.hits)/2)")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }

    // MARK: - 허스크
    public func toggleHusk() {
        if let w = husk, w.isVisible { w.close(); husk = nil; return }
        husk = nil
        let w = AHuskWindow(startPos: spawnPos(dx: 100)) { [weak self] tapped in
            self?.handleHuskTap(tapped)
        }
        husk = w
        w.start()
    }

    private func handleHuskTap(_ w: AHuskWindow) {
        if w.isHungry {
            RewardCenter.grant(xp: 3, "🏜️ 허스크 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); husk = nil
        } else {
            w.applyHunger()
            RewardCenter.say("🍖 허기! (20초)")
            SoundAndEffectsManager.shared.play(.gulp)
        }
    }

    // MARK: - 보고드
    public func toggleBogged() {
        if let w = bogged, w.isVisible { w.close(); bogged = nil; return }
        bogged = nil
        let w = ABoggedWindow(startPos: spawnPos(dx: -120)) { [weak self] tapped in
            self?.handleBoggedTap(tapped)
        }
        bogged = w
        w.start()
    }

    private func handleBoggedTap(_ w: ABoggedWindow) {
        if w.isPoisoned {
            RewardCenter.grant(xp: 3, "🐸 보고드 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); bogged = nil
        } else {
            w.applyPoison()
            RewardCenter.say("🍄 독화살! (시간 지나면 해제)")
            SoundAndEffectsManager.shared.play(.splash)
        }
    }

    // MARK: - 크리킹
    public func toggleCreaking() {
        if let w = creaking, w.isVisible { w.close(); creaking = nil; return }
        creaking = nil
        let w = ACreakingWindow(startPos: spawnPos(dx: 120)) { [weak self] tapped in
            self?.handleCreakingTap(tapped)
        }
        creaking = w
        w.start()
    }

    private func handleCreakingTap(_ w: ACreakingWindow) {
        if !ACreakingWindow.isNight() {
            RewardCenter.say("☀️ 낮이라 크리킹 소멸!")
            SoundAndEffectsManager.shared.play(.pop)
            w.close(); creaking = nil
            return
        }
        if w.isFrozen {
            RewardCenter.grant(xp: 4, "🌲 크리킹 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); creaking = nil
        } else {
            w.freeze()
            RewardCenter.say("🧊 눈 고정! 얼음 3초!")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }

    // MARK: - 엔더마이트
    public func toggleEndermite() {
        if let w = endermite, w.isVisible { w.close(); endermite = nil; return }
        endermite = nil
        let w = AEndermiteWindow(startPos: spawnPos(dx: 40)) { [weak self] tapped in
            self?.handleEndermiteTap(tapped)
        }
        endermite = w
        w.start()
    }

    private func handleEndermiteTap(_ w: AEndermiteWindow) {
        RewardCenter.grant(xp: 1, "🟪 엔더마이트 처치!")
        SoundAndEffectsManager.shared.play(.pop)
        w.close(); endermite = nil
    }

    // MARK: - 해골마 트랩
    public func toggleHorseTrap() {
        if let w = horseTrap, w.isVisible {
            w.close(); horseTrap = nil
            horseFlash?.close(); horseFlash = nil
            return
        }
        horseTrap = nil; horseFlash?.close(); horseFlash = nil
        let pos = spawnPos(dx: 0)
        let flash = ATrapFlashOverlay(center: pos)
        horseFlash = flash
        flash.show()
        let w = ASkeletonHorseTrapWindow(startPos: pos) { [weak self] tapped in
            self?.handleHorseTrapTap(tapped)
        }
        w.onDefeated = { [weak self] in self?.horseTrap = nil }
        horseTrap = w
        w.start()
    }

    private func handleHorseTrapTap(_ w: ASkeletonHorseTrapWindow) {
        if w.hit() {
            RewardCenter.grant(xp: 4, "🐴 안장 획득!")
            SoundAndEffectsManager.shared.play(.chime)
            w.close(); horseTrap = nil
        } else {
            RewardCenter.say("⚡ 해골마! (\(w.hits)/3)")
            SoundAndEffectsManager.shared.play(.explode)
        }
    }
}

// MARK: - 워든: 등장 디밍 + 스컬크 파티클 + 3타 격퇴

public final class AWardenDimOverlay: EntityWindow {
    public init(center: CGPoint) {
        super.init(contentRect: NSRect(x: center.x - 250, y: center.y - 150, width: 500, height: 300), ignoresMouse: true)
        contentView = AWardenDimView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
    }

    public func show() {
        orderFrontRegardless()
    }

    public override func close() {
        super.close()
    }
}

private final class AWardenDimView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 0.45)
        ctx.fill(bounds)
    }
}

public final class AWardenWindow: EntityWindow {
    public var position: CGPoint
    private var counter = HitCounter(maxHits: 3)
    public var hits: Int { counter.hits }
    public var onDefeated: (() -> Void)?
    private let onTap: (AWardenWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: AWardenDrawView?
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (AWardenWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AWardenDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.phase = self.phase
            self.drawView?.hits = self.hits
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        let defeated = counter.hit()
        drawView?.hits = counter.hits
        drawView?.needsDisplay = true
        return defeated
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

private final class AWardenDrawView: NSView {
    var phase: TimeInterval = 0
    var hits: Int = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let shake = hits > 0 ? CGFloat(hits) * 1.5 : 0
        let ox = sin(phase * 30.0) * shake * 0.3
        // 몸통 (짙은 청회색)
        ctx.setFillColor(red: 0.18, green: 0.24, blue: 0.28, alpha: 1.0)
        ctx.fill(CGRect(x: 22 + ox, y: 8, width: 40, height: 40))
        // 머리
        ctx.setFillColor(red: 0.15, green: 0.20, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: 26 + ox, y: 44, width: 32, height: 16))
        // 가슴 스컬크 심장 (청록 점멸)
        let glow = 0.5 + 0.5 * sin(phase * 6.0)
        ctx.setFillColor(red: 0.2, green: 0.9 - glow * 0.2, blue: 0.85, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 37 + ox, y: 26, width: 10, height: 12))
        // 눈 (흰 점)
        ctx.setFillColor(red: 0.9, green: 0.98, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30 + ox, y: 50, width: 4, height: 3))
        ctx.fillEllipse(in: CGRect(x: 50 + ox, y: 50, width: 4, height: 3))
        // 스컬크 파티클 3개
        ctx.setFillColor(red: 0.25, green: 0.85, blue: 0.8, alpha: 0.8)
        for i in 0..<3 {
            let px = 14 + CGFloat(i) * 24 + sin(phase * 3.0 + Double(i) * 2.0) * 4
            let py = 4 + (CGFloat(i) * 5).truncatingRemainder(dividingBy: 10)
            ctx.fillEllipse(in: CGRect(x: px, y: py, width: 5, height: 5))
        }
        // 뿔
        ctx.setFillColor(red: 0.10, green: 0.13, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 22 + ox, y: 54, width: 6, height: 8))
        ctx.fill(CGRect(x: 56 + ox, y: 54, width: 6, height: 8))
    }
}

// MARK: - 알레이: 주인 추적 + 전리품 배달 + 춤

public final class AAllayWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AAllayWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var deliverLeft: TimeInterval = 8.0
    private var danceLeft: TimeInterval = 0
    private var drawView: AAllayDrawView?
    private let panelW: CGFloat = 56
    private let panelH: CGFloat = 48
    private let loots = ["💎", "🍪", "🌸", "🧵"]

    public init(startPos: CGPoint, onTap: @escaping (AAllayWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AAllayDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.danceLeft > 0 { self.danceLeft -= 1.0 / 60.0 }
            // 주인 졸졸 추적
            let me = RewardCenter.me()
            if me != .zero {
                let dx = me.x + 40 - self.position.x
                let dy = me.y + 30 - self.position.y
                self.position.x += dx * 1.5 / 60.0
                self.position.y += dy * 1.5 / 60.0
            }
            let hover = sin(self.phase * 4.0) * 6.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hover))
            self.deliverLeft -= 1.0 / 60.0
            if self.deliverLeft <= 0 {
                self.deliverLeft = 8.0
                self.danceLeft = 1.5
                RewardCenter.say(self.loots.randomElement() ?? "💎")
                SoundAndEffectsManager.shared.play(.heart)
            }
            self.drawView?.dancing = self.danceLeft > 0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func dance() {
        danceLeft = 1.5
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

private final class AAllayDrawView: NSView {
    var phase: TimeInterval = 0
    var dancing = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let tilt: CGFloat = dancing ? sin(phase * 12.0) * 4.0 : 0
        // 몸 (하늘색 요정)
        ctx.setFillColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 20, y: 10, width: 16, height: 20))
        // 머리
        ctx.fillEllipse(in: CGRect(x: 21, y: 28, width: 14, height: 12))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 25, y: 33, width: 3, height: 3))
        ctx.fillEllipse(in: CGRect(x: 30, y: 33, width: 3, height: 3))
        // 날개 (흰 반투명)
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7)
        let flap = dancing ? abs(sin(phase * 14.0)) * 8.0 : 4.0
        ctx.fillEllipse(in: CGRect(x: 8 + tilt, y: 22, width: 12, height: 8 + flap))
        ctx.fillEllipse(in: CGRect(x: 36 - tilt, y: 22, width: 12, height: 8 + flap))
    }
}

// MARK: - 스니퍼: 땅 파기 후 고대 씨앗

public final class ASnifferWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (ASnifferWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var digCooldown = Cooldown()
    private var drawView: ASnifferDrawView?
    private let panelW: CGFloat = 88
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (ASnifferWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = ASnifferDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        digCooldown.trigger(6.0)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.digCooldown.tick(1.0 / 60.0)
            self.drawView?.phase = self.phase
            self.drawView?.ready = self.isReady
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public var isReady: Bool { digCooldown.ready }

    public func harvest() -> Bool {
        guard isReady else { return false }
        digCooldown.trigger(6.0)
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

private final class ASnifferDrawView: NSView {
    var phase: TimeInterval = 0
    var ready = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let dig = ready ? 0 : abs(sin(phase * 5.0)) * 4.0
        // 몸통 (진녹색 대형)
        ctx.setFillColor(red: 0.25, green: 0.5, blue: 0.28, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 10, y: 12, width: 56, height: 28))
        // 주둥이 (아래로 파기)
        ctx.fill(CGRect(x: 62, y: 10 - dig, width: 16, height: 14))
        // 코
        ctx.setFillColor(red: 0.18, green: 0.38, blue: 0.2, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 66, y: 12 - dig, width: 8, height: 6))
        // 눈
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 58, y: 28, width: 4, height: 4))
        // 등 가시
        ctx.setFillColor(red: 0.35, green: 0.62, blue: 0.35, alpha: 1.0)
        for x in [20, 32, 44] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 38, width: 6, height: 8))
        }
        // 다리
        ctx.setFillColor(red: 0.2, green: 0.42, blue: 0.22, alpha: 1.0)
        for x in [18, 34, 50] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 8, height: 12))
        }
        // 흙 파티클
        if !ready {
            ctx.setFillColor(red: 0.5, green: 0.38, blue: 0.28, alpha: 0.9)
            let px = 70 + sin(phase * 7.0) * 5
            ctx.fillEllipse(in: CGRect(x: px, y: 2, width: 6, height: 5))
        } else {
            // 고대 씨앗 반짝임
            ctx.setFillColor(red: 0.6, green: 1.0, blue: 0.4, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 68, y: 2, width: 8, height: 8))
        }
    }
}

// MARK: - 철골렘: 플레이어 근처 고정 + 순찰 펀치 + 장미

public final class AIronGolemWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AIronGolemWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var punchLeft: TimeInterval = 0
    private var drawView: AIronGolemDrawView?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, onTap: @escaping (AIronGolemWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AIronGolemDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.punchLeft > 0 { self.punchLeft -= 1.0 / 60.0 }
            // 플레이어 근처 고정 (120pt 안으로 유지)
            let me = RewardCenter.me()
            if me != .zero {
                let want = CGPoint(x: me.x - 90, y: me.y)
                self.position.x += (want.x - self.position.x) * 1.0 / 60.0
                self.position.y += (want.y - self.position.y) * 1.0 / 60.0
                self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            }
            self.drawView?.phase = self.phase
            self.drawView?.punching = self.punchLeft > 0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func punch() {
        punchLeft = 0.6
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

private final class AIronGolemDrawView: NSView {
    var phase: TimeInterval = 0
    var punching = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 다리
        ctx.setFillColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 2, width: 10, height: 18))
        ctx.fill(CGRect(x: 38, y: 2, width: 10, height: 18))
        // 몸통
        ctx.setFillColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 20, width: 36, height: 28))
        // 덩굴 무늬
        ctx.setFillColor(red: 0.35, green: 0.6, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 34, width: 8, height: 4))
        ctx.fill(CGRect(x: 40, y: 28, width: 8, height: 4))
        // 팔 (펀치 시 앞으로)
        let reach: CGFloat = punching ? 10.0 : 0
        ctx.setFillColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 22, width: 10, height: 24))
        ctx.fill(CGRect(x: 54 - reach, y: 22 + reach * 0.4, width: 10, height: 24))
        // 머리
        ctx.fill(CGRect(x: 24, y: 48, width: 24, height: 16))
        ctx.setFillColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 29, y: 54, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 39, y: 54, width: 4, height: 4))
        // 장미
        ctx.setFillColor(red: 1.0, green: 0.2, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 9, y: 46, width: 7, height: 7))
        ctx.setFillColor(red: 0.2, green: 0.6, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: 11, y: 42, width: 3, height: 5))
    }
}

// MARK: - 스트레이 + 슬로우 화살 미니 패널

public final class AStrayWindow: EntityWindow {
    public var position: CGPoint
    private var counter = HitCounter(maxHits: 2)
    public var hits: Int { counter.hits }
    public var onFire: ((CGPoint) -> Void)?
    private let onTap: (AStrayWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var fireCooldown = Cooldown()
    private var slowLeft: TimeInterval = 0
    private var wander = WanderState(speed: 26.0)
    private var drawView: AStrayDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (AStrayWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AStrayDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        fireCooldown.trigger(4.0)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.slowLeft > 0 { self.slowLeft -= 1.0 / 60.0 }
            let dt = 1.0 / 60.0
            self.wander.speed = self.slowLeft > 0 ? 8.0 : 26.0
            self.position.x += self.wander.tick(dt)
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.fireCooldown.tick(dt)
            if self.fireCooldown.ready {
                self.fireCooldown.trigger(6.0)
                self.onFire?(CGPoint(x: self.position.x, y: self.position.y + 24))
            }
            self.drawView?.slowed = self.slowLeft > 0
            self.drawView?.facingRight = self.wander.direction > 0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        return counter.hit()
    }

    public func applySlow() {
        slowLeft = 3.0
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

private final class AStrayDrawView: NSView {
    var phase: TimeInterval = 0
    var facingRight = true
    var slowed = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸 (회백색 해골)
        ctx.setFillColor(red: 0.8, green: 0.85, blue: 0.88, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 8, width: 20, height: 26))
        // 머리 + 눈 (푸른 눈)
        ctx.fill(CGRect(x: 20, y: 34, width: 24, height: 16))
        ctx.setFillColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 26, y: 40, width: 5, height: 5))
        ctx.fillEllipse(in: CGRect(x: 35, y: 40, width: 5, height: 5))
        // 낡은 누더기
        ctx.setFillColor(red: 0.55, green: 0.6, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 14, width: 20, height: 6))
        // 활
        ctx.setStrokeColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.strokeEllipse(in: CGRect(x: 46, y: 16, width: 10, height: 26))
        // 슬로우 표시
        if slowed {
            ctx.setFillColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 8, y: 44, width: 12, height: 8))
        }
        ctx.restoreGState()
    }
}

public final class AStrayArrowWindow: EntityWindow {
    private var tick: Timer?
    private var life: TimeInterval = 0
    private let onArrive: () -> Void
    private let panelW: CGFloat = 24
    private let panelH: CGFloat = 14

    public init(startPos: CGPoint, onArrive: @escaping () -> Void) {
        self.onArrive = onArrive
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: true)
        contentView = AStrayArrowView(frame: NSRect(x: 0, y: 0, width: panelW, height: panelH))
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.life += 1.0 / 60.0
            var f = self.frame
            f.origin.x -= 90.0 / 60.0
            self.setFrameOrigin(f.origin)
            if self.life >= 1.2 {
                t.invalidate()
                self.onArrive()
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

private final class AStrayArrowView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.6, green: 0.45, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 6, width: 16, height: 2))
        ctx.setFillColor(red: 0.5, green: 0.85, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 4, width: 6, height: 6))
    }
}

// MARK: - 허스크: 허기 디버프 20초 (시간 만료 자동 해제)

public final class AHuskWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isHungry = false
    private let onTap: (AHuskWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var hungerLeft: TimeInterval = 0
    private var wander = WanderState(speed: 20.0)
    private var drawView: AHuskDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (AHuskWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AHuskDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.hungerLeft > 0 {
                self.hungerLeft -= 1.0 / 60.0
                if self.hungerLeft <= 0 {
                    self.isHungry = false
                    RewardCenter.say("🍖 허기 해제!")
                }
            }
            self.position.x += self.wander.tick(1.0 / 60.0)
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.hungry = self.isHungry
            self.drawView?.remain = self.hungerLeft
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func applyHunger() {
        isHungry = true
        hungerLeft = 20.0
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

private final class AHuskDrawView: NSView {
    var phase: TimeInterval = 0
    var hungry = false
    var remain: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 몸 (황갈색 허스크)
        ctx.setFillColor(red: 0.78, green: 0.68, blue: 0.5, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 8, width: 24, height: 28))
        // 머리
        ctx.fill(CGRect(x: 18, y: 36, width: 28, height: 18))
        // 눈 (어두운 눈)
        ctx.setFillColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 24, y: 44, width: 5, height: 5))
        ctx.fillEllipse(in: CGRect(x: 35, y: 44, width: 5, height: 5))
        // 찢긴 옷
        ctx.setFillColor(red: 0.45, green: 0.38, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 20, width: 24, height: 6))
        // 허기 표시
        if hungry {
            ctx.setFillColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 46, y: 48, width: 12, height: 8))
            ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let secs = Int(ceil(remain))
            let label = "\(secs)" as NSString
            label.draw(at: CGPoint(x: 49, y: 48), withAttributes: [.font: NSFont.systemFont(ofSize: 7)])
        }
    }
}

// MARK: - 보고드: 독화살 + 버섯 (시간 만료 해제)

public final class ABoggedWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isPoisoned = false
    private let onTap: (ABoggedWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var poisonLeft: TimeInterval = 0
    private var wander = WanderState(speed: 22.0)
    private var drawView: ABoggedDrawView?
    private let panelW: CGFloat = 60
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (ABoggedWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = ABoggedDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.poisonLeft > 0 {
                self.poisonLeft -= 1.0 / 60.0
                if self.poisonLeft <= 0 {
                    self.isPoisoned = false
                    RewardCenter.say("🍄 독 해제!")
                }
            }
            self.position.x += self.wander.tick(1.0 / 60.0)
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.poisoned = self.isPoisoned
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func applyPoison() {
        isPoisoned = true
        poisonLeft = 8.0
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

private final class ABoggedDrawView: NSView {
    var phase: TimeInterval = 0
    var poisoned = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 몸 (녹갈색)
        ctx.setFillColor(red: 0.55, green: 0.6, blue: 0.4, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 8, width: 22, height: 26))
        // 머리 + 버섯 2개
        ctx.fill(CGRect(x: 16, y: 34, width: 26, height: 16))
        ctx.setFillColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 48, width: 10, height: 6))
        ctx.fillEllipse(in: CGRect(x: 30, y: 48, width: 10, height: 6))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 19, y: 50, width: 2, height: 2))
        ctx.fillEllipse(in: CGRect(x: 33, y: 50, width: 2, height: 2))
        // 눈
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 22, y: 40, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 32, y: 40, width: 4, height: 4))
        // 독 표시 (초록 기포)
        if poisoned {
            ctx.setFillColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 0.85)
            let by = 12 + sin(phase * 4.0) * 3
            ctx.fillEllipse(in: CGRect(x: 44, y: by, width: 8, height: 8))
            ctx.fillEllipse(in: CGRect(x: 48, y: by + 10, width: 5, height: 5))
        }
    }
}

// MARK: - 크리킹: 밤에만 눈 고정 얼음 3초, 낮 소멸

public final class ACreakingWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isFrozen = false
    private let onTap: (ACreakingWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var frozenLeft: TimeInterval = 0
    private var drawView: ACreakingDrawView?
    private let panelW: CGFloat = 68
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (ACreakingWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = ACreakingDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public static func isNight() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 18 || h < 6
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.frozenLeft > 0 {
                self.frozenLeft -= 1.0 / 60.0
                if self.frozenLeft <= 0 { self.isFrozen = false }
            }
            self.drawView?.frozen = self.isFrozen
            self.drawView?.daytime = !ACreakingWindow.isNight()
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func freeze() {
        isFrozen = true
        frozenLeft = 3.0
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

private final class ACreakingDrawView: NSView {
    var phase: TimeInterval = 0
    var frozen = false
    var daytime = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let alpha: CGFloat = daytime ? 0.35 : 1.0
        // 몸통 (창백한 나무 껍질)
        ctx.setFillColor(red: 0.75, green: 0.7, blue: 0.62, alpha: alpha)
        ctx.fill(CGRect(x: 22, y: 8, width: 24, height: 32))
        // 머리 + 세로 눈 3개 (주황 발광)
        ctx.fill(CGRect(x: 20, y: 40, width: 28, height: 18))
        if !daytime {
            let blink = 0.7 + 0.3 * sin(phase * 5.0)
            ctx.setFillColor(red: 1.0, green: CGFloat(0.6 * blink), blue: 0.1, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.5, green: 0.45, blue: 0.4, alpha: alpha)
        }
        for x in [26, 33, 40] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 45, width: 3, height: 9))
        }
        // 가지 팔
        ctx.setFillColor(red: 0.7, green: 0.65, blue: 0.57, alpha: alpha)
        ctx.fill(CGRect(x: 10, y: 20, width: 12, height: 5))
        ctx.fill(CGRect(x: 46, y: 20, width: 12, height: 5))
        // 얼음 표시
        if frozen {
            ctx.setFillColor(red: 0.6, green: 0.9, blue: 1.0, alpha: 0.85)
            ctx.fill(CGRect(x: 18, y: 4, width: 32, height: 6))
            ctx.fillEllipse(in: CGRect(x: 30, y: 56, width: 8, height: 6))
        }
    }
}

// MARK: - 엔더마이트: 작게 기어다님 + 1타

public final class AEndermiteWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AEndermiteWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var drawView: AEndermiteDrawView?
    private let panelW: CGFloat = 44
    private let panelH: CGFloat = 28

    public init(startPos: CGPoint, onTap: @escaping (AEndermiteWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = AEndermiteDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if Int(self.phase * 60.0) % 45 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            let wiggle = sin(self.phase * 10.0) * 6.0
            self.position.x += (self.dir * 70.0 + wiggle) / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.phase = self.phase
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

private final class AEndermiteDrawView: NSView {
    var phase: TimeInterval = 0
    var facingRight = true

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸 마디 3개 (보라)
        ctx.setFillColor(red: 0.55, green: 0.3, blue: 0.75, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 8, width: 12, height: 10))
        ctx.fillEllipse(in: CGRect(x: 16, y: 9, width: 12, height: 10))
        ctx.fillEllipse(in: CGRect(x: 26, y: 8, width: 12, height: 10))
        // 머리 + 빨간 눈
        ctx.setFillColor(red: 0.5, green: 0.25, blue: 0.7, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 32, y: 12, width: 8, height: 8))
        ctx.setFillColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 36, y: 15, width: 3, height: 3))
        // 다리 (꿈틀)
        ctx.setFillColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0)
        let lift = sin(phase * 12.0) * 1.5
        for (i, x) in ([10, 20, 30] as [CGFloat]).enumerated() {
            ctx.fill(CGRect(x: x, y: 2 + (i % 2 == 0 ? lift : -lift), width: 3, height: 7))
        }
        // 엔더 파티클
        ctx.setFillColor(red: 0.7, green: 0.4, blue: 1.0, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: 4 + sin(phase * 3.0) * 2, y: 20, width: 3, height: 3))
        ctx.restoreGState()
    }
}

// MARK: - 해골마 트랩: 번개 + 기마 2기 + 안장

public final class ATrapFlashOverlay: EntityWindow {
    private var tick: Timer?
    private var life: TimeInterval = 0

    public init(center: CGPoint) {
        super.init(contentRect: NSRect(x: center.x - 200, y: center.y - 100, width: 400, height: 300), ignoresMouse: true)
        contentView = ATrapFlashView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    public func show() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.explode)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.life += 1.0 / 60.0
            (self.contentView as? ATrapFlashView)?.life = self.life
            self.contentView?.needsDisplay = true
            if self.life >= 0.8 {
                self.close()
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

private final class ATrapFlashView: NSView {
    var life: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let alpha: CGFloat = max(0, 1.0 - CGFloat(life / 0.8))
        // 번개 볼트
        ctx.setStrokeColor(red: 0.7, green: 0.85, blue: 1.0, alpha: alpha)
        ctx.setLineWidth(4.0)
        ctx.move(to: CGPoint(x: 200, y: 290))
        ctx.addLine(to: CGPoint(x: 185, y: 220))
        ctx.addLine(to: CGPoint(x: 205, y: 170))
        ctx.addLine(to: CGPoint(x: 190, y: 100))
        ctx.strokePath()
        // 섬광
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: alpha * 0.5)
        ctx.fillEllipse(in: CGRect(x: 150, y: 60, width: 100, height: 60))
    }
}

public final class ASkeletonHorseTrapWindow: EntityWindow {
    public var position: CGPoint
    private var counter = HitCounter(maxHits: 3)
    public var hits: Int { counter.hits }
    public var onDefeated: (() -> Void)?
    private let onTap: (ASkeletonHorseTrapWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var wander = WanderState(speed: 34.0)
    private var drawView: ASkeletonHorseTrapDrawView?
    private let panelW: CGFloat = 88
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (ASkeletonHorseTrapWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = ASkeletonHorseTrapDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.position.x += self.wander.tick(1.0 / 60.0)
            let trot = abs(sin(self.phase * 8.0)) * 5.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + trot))
            self.drawView?.facingRight = self.wander.direction > 0
            self.drawView?.hits = self.hits
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        let defeated = counter.hit()
        drawView?.hits = counter.hits
        drawView?.needsDisplay = true
        return defeated
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

private final class ASkeletonHorseTrapDrawView: NSView {
    var phase: TimeInterval = 0
    var facingRight = true
    var hits: Int = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 해골마 몸통 (뼈 백색)
        ctx.setFillColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 14, width: 44, height: 16))
        // 갈비뼈 줄무늬
        ctx.setFillColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1.0)
        for x in [22, 30, 38, 46] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 14, width: 2, height: 16))
        }
        // 목 + 머리
        ctx.setFillColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0)
        ctx.fill(CGRect(x: 56, y: 24, width: 10, height: 16))
        ctx.fill(CGRect(x: 58, y: 36, width: 16, height: 10))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 66, y: 39, width: 4, height: 4))
        // 다리 (뼈)
        ctx.setFillColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1.0)
        let trot = sin(phase * 8.0) * 2.0
        ctx.fill(CGRect(x: 22, y: 2 + trot, width: 4, height: 12))
        ctx.fill(CGRect(x: 32, y: 2 - trot, width: 4, height: 12))
        ctx.fill(CGRect(x: 44, y: 2 + trot, width: 4, height: 12))
        ctx.fill(CGRect(x: 52, y: 2 - trot, width: 4, height: 12))
        // 기마 스켈레톤 2기 (안장 위 미니)
        ctx.setFillColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 28, y: 30, width: 8, height: 9))
        ctx.fillEllipse(in: CGRect(x: 40, y: 30, width: 8, height: 9))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 30, y: 34, width: 2, height: 2))
        ctx.fillEllipse(in: CGRect(x: 42, y: 34, width: 2, height: 2))
        // 안장
        ctx.setFillColor(red: 0.5, green: 0.32, blue: 0.2, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 28, width: 26, height: 5))
        ctx.restoreGState()
    }
}
