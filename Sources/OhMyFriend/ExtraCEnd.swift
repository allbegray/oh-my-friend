import AppKit
import CoreGraphics
import Foundation

// C분야 엔드 10종: 엔드시티·엔드배·드래곤부활·용의숨결·게이트웨이·엔드석벽돌·엔더상자·드래곤머리·크리스탈·공허구조 + EndCManager.
// EndCManager.shared.entries()에서 메뉴 연결한다.

public final class EndCManager {
    public static let shared = EndCManager()

    public var cityDone = false
    public var enderVault = 0

    private var city: CEndCityWindow?
    private var ship: CEndShipWindow?
    private var rebirth: CEndRebirthWindow?
    private let breathSlot = ToggleSlot<CEndBreathWindow>()
    private var gateA: CEndGatewayWindow?
    private var gateB: CEndGatewayWindow?
    private var brick: CEndBrickWallWindow?
    private var chest: CEnderChestWindow?
    private let headSlot = ToggleSlot<CDragonHeadWindow>()
    private var crystal: CCrystalWindow?
    private var rescueTimer: Timer?
    private var rescueActive = false

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🏯 엔드 시티" }, { [weak self] in self?.toggleCity() }),
            ExtraMenuEntry({ "🚢 엔드 배" }, { [weak self] in self?.toggleShip() }),
            ExtraMenuEntry({ "🐉 드래곤 부활전" }, { [weak self] in self?.toggleRebirth() }),
            ExtraMenuEntry({ "🐲 용의 숨결" }, { [weak self] in self?.toggleBreath() }),
            ExtraMenuEntry({ "🌀 게이트웨이" }, { [weak self] in self?.toggleGateway() }),
            ExtraMenuEntry({ "🧱 엔드 석벽돌" }, { [weak self] in self?.toggleBrick() }),
            ExtraMenuEntry({ "📦 엔더 상자" }, { [weak self] in self?.toggleChest() }),
            ExtraMenuEntry({ "🐲 드래곤 머리" }, { [weak self] in self?.toggleHead() }),
            ExtraMenuEntry({ "💎 크리스탈" }, { [weak self] in self?.toggleCrystal() }),
            ExtraMenuEntry({ [weak self] in self?.rescueTitle() ?? "🕳️ 공허 구조" }, { [weak self] in self?.toggleRescue() }),
        ]
    }

    private func rescueTitle() -> String {
        return rescueActive ? "🕳️ 공허 구조 (ON)" : "🕳️ 공허 구조"
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
        return CGPoint(x: me.x + dx, y: me.y)
    }

    // MARK: - 1. 엔드 시티

    public func toggleCity() {
        if let w = city, w.isVisible {
            w.close(); city = nil; return
        }
        city = nil
        let w = CEndCityWindow(startPos: spawnPos(dx: 0)) { [weak self] in
            guard let self = self else { return }
            self.cityDone = true
            RewardCenter.grant(xp: 5, "🏯 엔드 시티 정복!")
            SoundAndEffectsManager.shared.play(.chime)
            self.city?.close(); self.city = nil
        }
        city = w
        w.start()
    }

    // MARK: - 2. 엔드 배 (시티 완료 후 해금)

    public func toggleShip() {
        if let w = ship, w.isVisible {
            w.close(); ship = nil; return
        }
        ship = nil
        guard cityDone else {
            RewardCenter.say("🏯 엔드 시티를 먼저 완료!")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        let w = CEndShipWindow(startPos: spawnPos(dx: 80)) { [weak self] in
            RewardCenter.grant(xp: 6, "🪽 엘리트라 🪽 획득!")
            SoundAndEffectsManager.shared.play(.chime)
            self?.ship?.close(); self?.ship = nil
        }
        ship = w
        w.start()
    }

    // MARK: - 3. 드래곤 부활전

    public func toggleRebirth() {
        if let w = rebirth, w.isVisible {
            w.close(); rebirth = nil; return
        }
        rebirth = nil
        let w = CEndRebirthWindow(startPos: spawnPos(dx: -80)) { [weak self] in
            RewardCenter.grant(xp: 12, "🐉 드래곤 처치!")
            SoundAndEffectsManager.shared.play(.chime)
            self?.rebirth?.close(); self?.rebirth = nil
        }
        rebirth = w
        w.start()
    }

    // MARK: - 4. 용의 숨결

    public func toggleBreath() {
        let pos = spawnPos(dx: 0)
        breathSlot.toggle(make: {
            CEndBreathWindow(startPos: pos) { [weak self] tapped in
                self?.handleBreathTap(tapped)
            }
        }, start: { $0.start() })
    }

    private func handleBreathTap(_ w: CEndBreathWindow) {
        if RewardCenter.heldItemName?() == "빈 양동이 🪣" {
            w.collect()
            RewardCenter.grant(xp: 2, "🐲 용의 숨결 수집!")
            SoundAndEffectsManager.shared.play(.gulp)
        } else {
            RewardCenter.say("🐲 빈 양동이 🪣를 들고 클릭!")
            SoundAndEffectsManager.shared.play(.pop)
            w.puff()
        }
    }

    // MARK: - 5. 게이트웨이 (포털 2개 순간이동)

    public func toggleGateway() {
        if let a = gateA, a.isVisible {
            a.close(); gateA = nil
        }
        if let b = gateB, b.isVisible {
            b.close(); gateB = nil
        }
        if gateA != nil || gateB != nil {
            gateA = nil; gateB = nil; return
        }
        let base = spawnPos(dx: 0)
        let aPos = CGPoint(x: base.x - 110, y: base.y)
        let bPos = CGPoint(x: base.x + 110, y: base.y + 40)
        let a = CEndGatewayWindow(startPos: aPos, tag: 0) { [weak self] in self?.hopGateway(from: 0) }
        let b = CEndGatewayWindow(startPos: bPos, tag: 1) { [weak self] in self?.hopGateway(from: 1) }
        gateA = a; gateB = b
        a.start(); b.start()
    }

    private var gateCooldownUntil: Date = .distantPast

    private func hopGateway(from tag: Int) {
        guard Date() >= gateCooldownUntil else {
            RewardCenter.say("🌀 충전 중...")
            return
        }
        gateCooldownUntil = Date().addingTimeInterval(5.0)
        let dest: CGPoint?
        if tag == 0 {
            dest = gateB?.position
        } else {
            dest = gateA?.position
        }
        if let d = dest {
            RewardCenter.movePlayer?(d)
            RewardCenter.say("🌀 슝!")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    // MARK: - 6. 엔드 석벽돌 결계 (10분 유지)

    public func toggleBrick() {
        if let w = brick, w.isVisible {
            w.close(); brick = nil; return
        }
        brick = nil
        let w = CEndBrickWallWindow(startPos: spawnPos(dx: 0)) {
            RewardCenter.say("🛡️ 결계!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        brick = w
        w.start()
    }

    // MARK: - 7. 엔더 상자 (Manager 메모리 XP 10 단위 입출금)

    public func toggleChest() {
        if let w = chest, w.isVisible {
            w.close(); chest = nil; return
        }
        chest = nil
        let w = CEnderChestWindow(startPos: spawnPos(dx: 0), vault: { [weak self] in self?.enderVault ?? 0 }) { [weak self] opened in
            guard let self = self else { return }
            if opened {
                if self.enderVault >= 10 {
                    self.enderVault -= 10
                    RewardCenter.grant(xp: 10, "📦 엔더 상자 인출!")
                    SoundAndEffectsManager.shared.play(.chime)
                } else {
                    self.enderVault += 10
                    RewardCenter.say("📦 보관 +10 (합계 \(self.enderVault))")
                    SoundAndEffectsManager.shared.play(.pop)
                }
            } else {
                RewardCenter.say("📦 닫힘 (보관 \(self.enderVault))")
                SoundAndEffectsManager.shared.play(.pop)
            }
        }
        chest = w
        w.start()
    }

    // MARK: - 8. 드래곤 머리

    public func toggleHead() {
        let pos = spawnPos(dx: 60)
        headSlot.toggle(make: {
            CDragonHeadWindow(startPos: pos) { worn in
                if worn {
                    RewardCenter.say("🐲 드래곤 머리 착용!")
                } else {
                    RewardCenter.say("🐲 벗기 완료")
                }
                SoundAndEffectsManager.shared.play(.pop)
            }
        }, start: { $0.start() })
    }

    // MARK: - 9. 엔드 크리스탈 (대폭발)

    public func toggleCrystal() {
        if let w = crystal, w.isVisible {
            w.close(); crystal = nil; return
        }
        crystal = nil
        let w = CCrystalWindow(startPos: spawnPos(dx: -60)) { [weak self] in
            RewardCenter.say("💥 대폭발!")
            SoundAndEffectsManager.shared.play(.chime)
            self?.clearBlastArea()
            self?.crystal?.close(); self?.crystal = nil
        }
        crystal = w
        w.start()
    }

    private func clearBlastArea() {
        // 폭발 주변 정리: 임시 연출 창들을 함께 닫는다.
        breathSlot.clear()
        if let w = brick, w.isVisible { w.close(); brick = nil }
    }

    // MARK: - 10. 공허 구조 (30분 타이머 만료 시 자동 구조 1회)

    public func toggleRescue() {
        if rescueActive {
            rescueTimer?.invalidate()
            rescueTimer = nil
            rescueActive = false
            RewardCenter.say("🕳️ 구조 대기 해제")
            return
        }
        rescueActive = true
        RewardCenter.say("🕳️ 공허 낙하 감시 ON (30분)")
        SoundAndEffectsManager.shared.play(.pop)
        rescueTimer?.invalidate()
        rescueTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: false) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.rescueActive = false
            self.rescueTimer?.invalidate()
            self.rescueTimer = nil
            RewardCenter.grant(xp: 1, "🪂 구조!")
            SoundAndEffectsManager.shared.play(.chime)
        }
        if let t = rescueTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }
}

// MARK: - 1. 시티: 하늘 상자 3개 순차 파밍

public final class CEndCityWindow: EntityWindow {
    private let onDone: () -> Void
    private var opened = 0
    private var drawView: CEndCityDrawView?
    private let panelW: CGFloat = 220
    private let panelH: CGFloat = 96

    public init(startPos: CGPoint, onDone: @escaping () -> Void) {
        self.onDone = onDone
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y + 60, width: panelW, height: panelH), ignoresMouse: false)
        let view = CEndCityDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        guard opened < 3 else { return }
        opened += 1
        drawView?.opened = opened
        drawView?.needsDisplay = true
        let loots = ["💎 다이아!", "⬜ 철!", "🪶 엘리트라 조각!"]
        RewardCenter.say(loots[min(opened - 1, 2)])
        SoundAndEffectsManager.shared.play(.pop)
        if opened >= 3 {
            let cb = onDone
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cb() }
        }
    }
}

private final class CEndCityDrawView: NSView {
    var opened = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 하늘 도시 기단 (엔드 석)
        ctx.setFillColor(red: 0.92, green: 0.93, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 0, width: bounds.width - 12, height: 18))
        // 상자 3개
        for i in 0..<3 {
            let x: CGFloat = 22 + CGFloat(i) * 68
            let isOpen = opened > i
            ctx.setFillColor(red: 0.55, green: 0.36, blue: 0.16, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: 24, width: 52, height: 26))
            ctx.setFillColor(red: 0.42, green: 0.26, blue: 0.10, alpha: 1.0)
            if isOpen {
                ctx.fill(CGRect(x: x, y: 50, width: 52, height: 6))
                ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.55, alpha: 0.9)
                ctx.fill(CGRect(x: x + 12, y: 56, width: 28, height: 10))
            } else {
                ctx.fill(CGRect(x: x, y: 50, width: 52, height: 14))
                ctx.setFillColor(red: 0.85, green: 0.70, blue: 0.25, alpha: 1.0)
                ctx.fill(CGRect(x: x + 21, y: 46, width: 10, height: 10))
            }
        }
        // 자수정 기둥
        ctx.setFillColor(red: 0.65, green: 0.45, blue: 0.80, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 18, width: 8, height: 60))
        ctx.fill(CGRect(x: bounds.width - 8, y: 18, width: 8, height: 60))
    }
}

// MARK: - 2. 엔드 배

public final class CEndShipWindow: EntityWindow {
    private let onLoot: () -> Void
    private var done = false
    private var drawView: CEndShipDrawView?
    private let panelW: CGFloat = 120
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, onLoot: @escaping () -> Void) {
        self.onLoot = onLoot
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y + 90, width: panelW, height: panelH), ignoresMouse: false)
        let view = CEndShipDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        guard !done else { return }
        done = true
        drawView?.claimed = true
        drawView?.needsDisplay = true
        onLoot()
    }
}

private final class CEndShipDrawView: NSView {
    var claimed = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 선체 (공중에 뜬 배)
        ctx.setFillColor(red: 0.72, green: 0.58, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 18, width: 100, height: 26))
        ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.26, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 8, width: 76, height: 12))
        // 돛대 + 깃발
        ctx.fill(CGRect(x: 58, y: 44, width: 5, height: 24))
        ctx.setFillColor(red: 0.85, green: 0.30, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: 63, y: 56, width: 22, height: 12))
        if claimed {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 46, y: 24, width: 28, height: 14))
        }
    }
}

// MARK: - 3. 드래곤 부활전: 크리스탈 4개 설치 → 5타 레이드

public final class CEndRebirthWindow: EntityWindow {
    private let onSlain: () -> Void
    private var crystals = 0
    private var raid = HitCounter(maxHits: 5)
    private var hits: Int { raid.hits }
    private var drawView: CEndRebirthDrawView?
    private let panelW: CGFloat = 150
    private let panelH: CGFloat = 110

    public init(startPos: CGPoint, onSlain: @escaping () -> Void) {
        self.onSlain = onSlain
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = CEndRebirthDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        if crystals < 4 {
            crystals += 1
            RewardCenter.say("💎 크리스탈 설치 \(crystals)/4")
            SoundAndEffectsManager.shared.play(.pop)
        } else if raid.hits < 5 {
            _ = raid.hit()
            RewardCenter.say("🐉 격타 \(raid.hits)/5!")
            SoundAndEffectsManager.shared.play(.pop)
            if raid.hits >= 5 {
                let cb = onSlain
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { cb() }
            }
        }
        drawView?.crystals = crystals
        drawView?.hits = hits
        drawView?.needsDisplay = true
    }
}

private final class CEndRebirthDrawView: NSView {
    var crystals = 0
    var hits = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 출구 포털 기단
        ctx.setFillColor(red: 0.30, green: 0.30, blue: 0.32, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 6, width: 110, height: 16))
        // 크리스탈 4개 슬롯
        for i in 0..<4 {
            let x: CGFloat = 28 + CGFloat(i) * 28
            if crystals > i {
                ctx.setFillColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0)
                ctx.fillEllipse(in: CGRect(x: x, y: 26, width: 16, height: 20))
            } else {
                ctx.setStrokeColor(red: 0.70, green: 0.70, blue: 0.75, alpha: 1.0)
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: CGRect(x: x, y: 26, width: 16, height: 20))
            }
        }
        // 드래곤 실루엣 (부활 후 등장)
        if crystals >= 4 {
            let wob = CGFloat(hits) * 2.0
            ctx.setFillColor(red: 0.25, green: 0.22, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 45, y: 56 + wob, width: 60, height: 30))
            ctx.fillEllipse(in: CGRect(x: 95, y: 66 + wob, width: 22, height: 16))
            // 날개
            ctx.setFillColor(red: 0.40, green: 0.35, blue: 0.48, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 78 + wob, width: 34, height: 10))
            ctx.fill(CGRect(x: 86, y: 78 + wob, width: 34, height: 10))
            // 체력바
            ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
            ctx.fill(CGRect(x: 30, y: 96, width: 90, height: 6))
            ctx.setFillColor(red: 0.85, green: 0.25, blue: 0.35, alpha: 1.0)
            let left = CGFloat(5 - hits) / 5.0
            ctx.fill(CGRect(x: 30, y: 96, width: 90 * max(0, left), height: 6))
        }
    }
}

// MARK: - 4. 용의 숨결 브레스 존

public final class CEndBreathWindow: EntityWindow {
    private let onTap: (CEndBreathWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var puffs = 0
    private var drawView: CEndBreathDrawView?

    public init(startPos: CGPoint, onTap: @escaping (CEndBreathWindow) -> Void) {
        self.onTap = onTap
        let size = NSSize(width: 150, height: 70)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CEndBreathDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.puffs = self.puffs
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func collect() {
        puffs += 1
        drawView?.puffs = puffs
        drawView?.needsDisplay = true
    }

    public func puff() {
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

private final class CEndBreathDrawView: NSView {
    var phase: TimeInterval = 0
    var puffs = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 보라 브레스 존
        let pulse = 0.35 + 0.15 * sin(CGFloat(phase * 4.0))
        ctx.setFillColor(red: 0.65, green: 0.25, blue: 0.85, alpha: pulse)
        ctx.fillEllipse(in: CGRect(x: 10, y: 6, width: bounds.width - 20, height: 52))
        ctx.setFillColor(red: 0.80, green: 0.50, blue: 1.0, alpha: 0.5)
        for i in 0..<5 {
            let x = 24 + CGFloat(i) * 24 + sin(CGFloat(phase * 3.0) + CGFloat(i)) * 4
            ctx.fillEllipse(in: CGRect(x: x, y: 20 + CGFloat((i * 7) % 20), width: 10, height: 10))
        }
        if puffs > 0 {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
            ctx.fill(CGRect(x: bounds.width / 2 - 20, y: 56, width: 40, height: 10))
        }
    }
}

// MARK: - 5. 게이트웨이 포털

public final class CEndGatewayWindow: EntityWindow {
    public var position: CGPoint
    private let onHop: () -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: CEndGatewayDrawView?
    private let panelW: CGFloat = 56
    private let panelH: CGFloat = 84

    public init(startPos: CGPoint, tag: Int, onHop: @escaping () -> Void) {
        self.position = startPos
        self.onHop = onHop
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = CEndGatewayDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
        _ = tag
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        onHop()
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class CEndGatewayDrawView: NSView {
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 베드락 틀
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 18, y: 4, width: 36, height: 76))
        // 소용돌이 포털
        let swirl = sin(CGFloat(phase * 5.0)) * 3
        ctx.setFillColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 0.85)
        ctx.fillEllipse(in: CGRect(x: cx - 11 + swirl, y: 16, width: 22, height: 52))
        ctx.setFillColor(red: 0.45, green: 0.30, blue: 0.85, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: cx - 7 - swirl, y: 26, width: 14, height: 32))
    }
}

// MARK: - 6. 엔드 석벽돌 결계 (10분 유지)

public final class CEndBrickWallWindow: EntityWindow {
    private let onTap: () -> Void
    private var lifeTimer: Timer?
    private var drawView: CEndBrickWallDrawView?

    public init(startPos: CGPoint, onTap: @escaping () -> Void) {
        self.onTap = onTap
        let size = NSSize(width: 170, height: 90)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CEndBrickWallDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🛡️ 결계! (10분)")
        lifeTimer?.invalidate()
        lifeTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] t in
            t.invalidate()
            self?.close()
        }
        if let t = lifeTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        onTap()
        drawView?.flash()
    }

    public override func close() {
        lifeTimer?.invalidate()
        lifeTimer = nil
        super.close()
    }
}

private final class CEndBrickWallDrawView: NSView {
    private var glow = false

    func flash() {
        glow = true
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.glow = false
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 엔드 석벽돌 2단
        for row in 0..<2 {
            for col in 0..<4 {
                let x = 6 + CGFloat(col) * 40
                let y = 14 + CGFloat(row) * 26
                ctx.setFillColor(red: 0.90, green: 0.91, blue: 0.74, alpha: 1.0)
                ctx.fill(CGRect(x: x, y: y, width: 38, height: 24))
                ctx.setStrokeColor(red: 0.70, green: 0.71, blue: 0.55, alpha: 1.0)
                ctx.setLineWidth(1.5)
                ctx.stroke(CGRect(x: x, y: y, width: 38, height: 24))
            }
        }
        if glow {
            ctx.setStrokeColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.9)
            ctx.setLineWidth(3.0)
            ctx.strokeEllipse(in: CGRect(x: 2, y: 2, width: bounds.width - 4, height: bounds.height - 4))
        }
    }
}

// MARK: - 7. 엔더 상자 (열기/닫기 + XP 10 입출금)

public final class CEnderChestWindow: EntityWindow {
    private let vault: () -> Int
    private let onToggle: (Bool) -> Void
    private var isOpened = false
    private var drawView: CEnderChestDrawView?

    public init(startPos: CGPoint, vault: @escaping () -> Int, onToggle: @escaping (Bool) -> Void) {
        self.vault = vault
        self.onToggle = onToggle
        let size = NSSize(width: 92, height: 76)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CEnderChestDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        isOpened.toggle()
        drawView?.isOpened = isOpened
        drawView?.vaultText = "\(vault())"
        drawView?.needsDisplay = true
        onToggle(isOpened)
    }
}

private final class CEnderChestDrawView: NSView {
    var isOpened = false
    var vaultText = "0"

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        // 흑요석 상자 본체
        ctx.setFillColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 4, width: w - 20, height: 32))
        if isOpened {
            ctx.setFillColor(red: 0.65, green: 0.25, blue: 0.85, alpha: 1.0)
            ctx.fill(CGRect(x: 10, y: 36, width: w - 20, height: 8))
            ctx.setFillColor(red: 0.80, green: 0.55, blue: 1.0, alpha: 0.9)
            ctx.fill(CGRect(x: w / 2 - 14, y: 46, width: 28, height: 12))
        } else {
            ctx.setFillColor(red: 0.18, green: 0.15, blue: 0.24, alpha: 1.0)
            ctx.fill(CGRect(x: 10, y: 36, width: w - 20, height: 18))
            ctx.setFillColor(red: 0.85, green: 0.55, blue: 1.0, alpha: 1.0)
            ctx.fill(CGRect(x: w / 2 - 5, y: 30, width: 10, height: 10))
        }
        let text = NSAttributedString(
            string: vaultText,
            attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.labelColor]
        )
        text.draw(at: NSPoint(x: 6, y: 60))
    }
}

// MARK: - 8. 드래곤 머리 (쓰기 토글 + 불꽃 파티클)

public final class CDragonHeadWindow: EntityWindow {
    private let onWear: (Bool) -> Void
    private var worn = false
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: CDragonHeadDrawView?

    public init(startPos: CGPoint, onWear: @escaping (Bool) -> Void) {
        self.onWear = onWear
        let size = NSSize(width: 72, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CDragonHeadDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 30.0
            self.drawView?.phase = self.phase
            self.drawView?.worn = self.worn
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        worn.toggle()
        drawView?.worn = worn
        drawView?.needsDisplay = true
        onWear(worn)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class CDragonHeadDrawView: NSView {
    var worn = false
    var phase: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 드래곤 머리 (회흑 + 뿔 + 눈)
        ctx.setFillColor(red: 0.28, green: 0.25, blue: 0.32, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 18, width: 40, height: 34))
        ctx.setFillColor(red: 0.85, green: 0.80, blue: 0.75, alpha: 1.0)
        ctx.fill(CGRect(x: 12, y: 44, width: 10, height: 12))
        ctx.fill(CGRect(x: 50, y: 44, width: 10, height: 12))
        ctx.setFillColor(red: 0.75, green: 0.45, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 24, y: 34, width: 8, height: 8))
        ctx.fillEllipse(in: CGRect(x: 40, y: 34, width: 8, height: 8))
        ctx.setFillColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1.0)
        ctx.fill(CGRect(x: 28, y: 22, width: 16, height: 6))
        if worn {
            // 착용 중 불꽃 파티클
            for i in 0..<4 {
                let fy = 54 + CGFloat((phase * 30).truncatingRemainder(dividingBy: 14)) + CGFloat(i * 3)
                let fx = 24 + CGFloat(i) * 8 + sin(CGFloat(phase * 6.0) + CGFloat(i)) * 3
                ctx.setFillColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.9)
                ctx.fillEllipse(in: CGRect(x: fx, y: min(fy, 68), width: 5, height: 5))
            }
        }
    }
}

// MARK: - 9. 엔드 크리스탈 (대폭발 플래시)

public final class CCrystalWindow: EntityWindow {
    private let onBoom: () -> Void
    private var exploded = false
    private var flashCooldown = Cooldown()
    private var tick: Timer?
    private var drawView: CCrystalDrawView?

    public init(startPos: CGPoint, onBoom: @escaping () -> Void) {
        self.onBoom = onBoom
        let size = NSSize(width: 80, height: 100)
        super.init(contentRect: NSRect(x: startPos.x - size.width / 2, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CCrystalDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if !self.flashCooldown.ready {
                self.flashCooldown.tick(1.0 / 30.0)
                self.drawView?.flash = !self.flashCooldown.ready
                self.drawView?.needsDisplay = true
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        guard !exploded else { return }
        exploded = true
        flashCooldown.trigger(0.5)
        drawView?.flash = true
        drawView?.needsDisplay = true
        let cb = onBoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { cb() }
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class CCrystalDrawView: NSView {
    var flash = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if flash {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
            ctx.fill(bounds)
            ctx.setFillColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 10, y: 20, width: bounds.width - 20, height: bounds.width - 20))
            return
        }
        // 흑요석 기단
        ctx.setFillColor(red: 0.12, green: 0.10, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 4, width: 52, height: 14))
        // 크리스탈
        ctx.setFillColor(red: 0.90, green: 0.60, blue: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 30, width: 20, height: 34))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85)
        ctx.fill(CGRect(x: 34, y: 44, width: 5, height: 16))
        // 불꽃 받침
        ctx.setFillColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: 32, y: 20, width: 16, height: 10))
    }
}
