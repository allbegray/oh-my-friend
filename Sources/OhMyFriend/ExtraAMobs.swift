import AppKit
import CoreGraphics
import Foundation
import SceneKit

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
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var heart: SCNNode?
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (AWardenWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let r = BipedRig(headColor: .rgb(0.15, 0.20, 0.24), torsoColor: .rgb(0.18, 0.24, 0.28), limbColor: .rgb(0.10, 0.13, 0.15))
        r.scale = SCNVector3(0.75, 0.75, 0.75)
        let heart = vbox(0.12, 0.16, 0.06, .glow(0.2, 0.8, 0.75))
        heart.position = SCNVector3(0, -0.05, 0.14)
        r.torso.addChildNode(heart)
        self.heart = heart
        let eyeMat = VoxelColor.rgb(0.9, 0.98, 1.0)
        for sx in [-0.12, 0.12] as [CGFloat] {
            let eye = vbox(0.07, 0.06, 0.02, eyeMat)
            eye.position = SCNVector3(sx, 0.08, 0.26)
            r.head.addChildNode(eye)
        }
        for sx in [-0.28, 0.28] as [CGFloat] {
            let horn = vbox(0.10, 0.22, 0.10, .rgb(0.10, 0.13, 0.15))
            horn.position = SCNVector3(sx, 0.30, 0)
            r.head.addChildNode(horn)
        }
        for sx in [-0.18, 0.18] as [CGFloat] {
            let tendril = vbox(0.06, 0.30, 0.06, .rgb(0.25, 0.85, 0.80))
            tendril.position = SCNVector3(sx, -0.15, 0.24)
            r.head.addChildNode(tendril)
        }
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.rig?.walk(1.0 / 60.0)
            let glow = 0.5 + 0.5 * CGFloat(sin(self.phase * 6.0))
            self.heart?.opacity = 0.6 + 0.4 * glow
            if self.hits > 0 {
                self.rig?.position.x = CGFloat(sin(self.phase * 30.0)) * CGFloat(self.hits) * 0.01
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        let defeated = counter.hit()
        rig?.attack()
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

// MARK: - 알레이: 주인 추적 + 전리품 배달 + 춤

public final class AAllayWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AAllayWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var deliverLeft: TimeInterval = 8.0
    private var danceLeft: TimeInterval = 0
    private var sceneView: MobSceneView?
    private var rig: FlyerRig?
    private let panelW: CGFloat = 56
    private let panelH: CGFloat = 48
    private let loots = ["💎", "🍪", "🌸", "🧵"]

    public init(startPos: CGPoint, onTap: @escaping (AAllayWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let r = FlyerRig(bodyColor: .rgb(0.55, 0.85, 1.0), wingColor: .rgb(1.0, 1.0, 1.0))
        let eyeMat = VoxelColor.rgb(0.1, 0.1, 0.15)
        for sx in [-0.07, 0.07] as [CGFloat] {
            let eye = vbox(0.06, 0.06, 0.02, eyeMat)
            eye.position = SCNVector3(sx, 0.10, 0.17)
            r.body.addChildNode(eye)
        }
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.flap(1.0 / 60.0)
            if self.danceLeft > 0 {
                self.rig?.eulerAngles.z = CGFloat(sin(self.phase * 12.0)) * 0.2
            } else {
                self.rig?.eulerAngles.z = 0
            }
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func dance() {
        danceLeft = 1.5
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

// MARK: - 스니퍼: 땅 파기 후 고대 씨앗

public final class ASnifferWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (ASnifferWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var digCooldown = Cooldown()
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var snout: SCNNode?
    private var seed: SCNNode?
    private let panelW: CGFloat = 88
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (ASnifferWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let green = VoxelColor.rgb(0.25, 0.5, 0.28)
        let darkGreen = VoxelColor.rgb(0.2, 0.42, 0.22)
        let r = QuadRig(bodyColor: green, headColor: green, legColor: darkGreen, tailColor: nil)
        r.scale = SCNVector3(1.2, 1.2, 1.2)
        let snout = vbox(0.22, 0.20, 0.22, darkGreen)
        snout.position = SCNVector3(0, -0.10, 0.34)
        r.head.addChildNode(snout)
        self.snout = snout
        let nose = vbox(0.12, 0.08, 0.06, VoxelColor.rgb(0.18, 0.38, 0.2))
        nose.position = SCNVector3(0, -0.12, 0.48)
        r.head.addChildNode(nose)
        let eye = vbox(0.07, 0.07, 0.02, VoxelColor.rgb(0.08, 0.08, 0.08))
        eye.position = SCNVector3(0.14, 0.08, 0.25)
        r.head.addChildNode(eye)
        for sx in [-0.12, 0.0, 0.12] as [CGFloat] {
            let spike = vbox(0.10, 0.16, 0.10, VoxelColor.rgb(0.35, 0.62, 0.35))
            spike.position = SCNVector3(sx, 0.33, -0.05)
            r.body.addChildNode(spike)
        }
        let seed = vbox(0.12, 0.12, 0.12, .glow(0.6, 1.0, 0.4))
        seed.position = SCNVector3(0.30, -0.30, 0.30)
        seed.isHidden = true
        r.body.addChildNode(seed)
        self.seed = seed
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
            let digging = !self.isReady
            self.snout?.position.y = -0.10 + (digging ? CGFloat(abs(sin(self.phase * 5.0))) * -0.06 : 0)
            self.seed?.isHidden = digging
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

// MARK: - 철골렘: 플레이어 근처 고정 + 순찰 펀치 + 장미

public final class AIronGolemWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AIronGolemWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var punchLeft: TimeInterval = 0
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 72

    public init(startPos: CGPoint, onTap: @escaping (AIronGolemWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let r = BipedRig(headColor: .rgb(0.82, 0.82, 0.85), torsoColor: .rgb(0.82, 0.82, 0.85), limbColor: .rgb(0.78, 0.78, 0.80))
        r.scale = SCNVector3(0.8, 0.8, 0.8)
        let mid = vbox(0.50, 0.35, 0.30, .rgb(0.82, 0.82, 0.85))
        mid.position = SCNVector3(0, -0.55, 0)
        r.torso.addChildNode(mid)
        let base = vbox(0.62, 0.40, 0.36, .rgb(0.82, 0.82, 0.85))
        base.position = SCNVector3(0, -0.95, 0)
        r.torso.addChildNode(base)
        let vine = vbox(0.20, 0.08, 0.24, .rgb(0.35, 0.6, 0.3))
        vine.position = SCNVector3(0, 0.10, 0)
        r.torso.addChildNode(vine)
        for sx in [-0.12, 0.12] as [CGFloat] {
            let eye = vbox(0.08, 0.10, 0.04, .glow(1.0, 0.5, 0.2))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            r.head.addChildNode(eye)
        }
        let rose = vbox(0.10, 0.10, 0.10, .rgb(1.0, 0.2, 0.25))
        rose.position = SCNVector3(0, -0.72, 0.06)
        r.armL.addChildNode(rose)
        let stem = vbox(0.04, 0.12, 0.04, .rgb(0.2, 0.6, 0.25))
        stem.position = SCNVector3(0, -0.62, 0.06)
        r.armL.addChildNode(stem)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func punch() {
        punchLeft = 0.6
        rig?.attack()
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
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var slowMark: SCNNode?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (AStrayWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let bone = VoxelColor.rgb(0.8, 0.85, 0.88)
        let rag = VoxelColor.rgb(0.55, 0.6, 0.65)
        let r = BipedRig(headColor: bone, torsoColor: bone, limbColor: rag)
        for sx in [-0.10, 0.10] as [CGFloat] {
            let eye = vbox(0.08, 0.08, 0.02, .glow(0.4, 0.8, 1.0))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            r.head.addChildNode(eye)
        }
        let bow = vbox(0.05, 0.55, 0.05, VoxelColor.rgb(0.45, 0.32, 0.2))
        bow.position = SCNVector3(0.32, -0.30, 0)
        r.torso.addChildNode(bow)
        let mark = vbox(0.16, 0.10, 0.16, .glow(0.4, 0.7, 1.0))
        mark.position = SCNVector3(-0.30, 0.45, 0)
        mark.isHidden = true
        r.torso.addChildNode(mark)
        self.slowMark = mark
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(dt)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? CGFloat(Double.pi / 2.0) : CGFloat(-Double.pi / 2.0)
            self.slowMark?.isHidden = self.slowLeft <= 0
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        rig?.attack()
        return counter.hit()
    }

    public func applySlow() {
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
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var hungerMark: SCNNode?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (AHuskWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let sand = VoxelColor.rgb(0.78, 0.68, 0.5)
        let r = BipedRig(headColor: sand, torsoColor: sand, limbColor: .rgb(0.45, 0.38, 0.3))
        let tear = vbox(0.38, 0.10, 0.24, .rgb(0.45, 0.38, 0.3))
        tear.position = SCNVector3(0, -0.15, 0)
        r.torso.addChildNode(tear)
        for sx in [-0.10, 0.10] as [CGFloat] {
            let eye = vbox(0.08, 0.08, 0.02, VoxelColor.rgb(0.2, 0.15, 0.1))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            r.head.addChildNode(eye)
        }
        let mark = vbox(0.16, 0.12, 0.16, .glow(1.0, 0.6, 0.2))
        mark.position = SCNVector3(0.30, 0.45, 0)
        mark.isHidden = true
        r.torso.addChildNode(mark)
        self.hungerMark = mark
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? CGFloat(Double.pi / 2.0) : CGFloat(-Double.pi / 2.0)
            self.hungerMark?.isHidden = !self.isHungry
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

// MARK: - 보고드: 독화살 + 버섯 (시간 만료 해제)

public final class ABoggedWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isPoisoned = false
    private let onTap: (ABoggedWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var poisonLeft: TimeInterval = 0
    private var wander = WanderState(speed: 22.0)
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var poisonPuff: SCNNode?
    private let panelW: CGFloat = 60
    private let panelH: CGFloat = 56

    public init(startPos: CGPoint, onTap: @escaping (ABoggedWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let bog = VoxelColor.rgb(0.55, 0.6, 0.4)
        let r = BipedRig(headColor: bog, torsoColor: bog, limbColor: .rgb(0.45, 0.52, 0.34))
        for sx in [-0.14, 0.14] as [CGFloat] {
            let shroom = vbox(0.14, 0.08, 0.14, .rgb(0.85, 0.2, 0.2))
            shroom.position = SCNVector3(sx, 0.30, 0)
            r.head.addChildNode(shroom)
            let dot = vbox(0.04, 0.04, 0.02, .rgb(1.0, 1.0, 1.0))
            dot.position = SCNVector3(sx, 0.32, 0.08)
            r.head.addChildNode(dot)
        }
        for sx in [-0.10, 0.10] as [CGFloat] {
            let eye = vbox(0.07, 0.07, 0.02, VoxelColor.rgb(0.1, 0.1, 0.1))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            r.head.addChildNode(eye)
        }
        let bow = vbox(0.05, 0.50, 0.05, VoxelColor.rgb(0.45, 0.32, 0.2))
        bow.position = SCNVector3(0.32, -0.30, 0)
        r.torso.addChildNode(bow)
        let puff = vbox(0.14, 0.14, 0.14, .glow(0.3, 0.9, 0.3))
        puff.position = SCNVector3(0.34, 0.30, 0)
        puff.isHidden = true
        r.torso.addChildNode(puff)
        self.poisonPuff = puff
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? CGFloat(Double.pi / 2.0) : CGFloat(-Double.pi / 2.0)
            self.poisonPuff?.isHidden = !self.isPoisoned
            self.poisonPuff?.position.y = 0.30 + CGFloat(sin(self.phase * 4.0)) * 0.05
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

// MARK: - 크리킹: 밤에만 눈 고정 얼음 3초, 낮 소멸

public final class ACreakingWindow: EntityWindow {
    public var position: CGPoint
    public private(set) var isFrozen = false
    private let onTap: (ACreakingWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var frozenLeft: TimeInterval = 0
    private var sceneView: MobSceneView?
    private var rig: BipedRig?
    private var ice: SCNNode?
    private let panelW: CGFloat = 68
    private let panelH: CGFloat = 64

    public init(startPos: CGPoint, onTap: @escaping (ACreakingWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let bark = VoxelColor.rgb(0.75, 0.7, 0.62)
        let darkBark = VoxelColor.rgb(0.7, 0.65, 0.57)
        let r = BipedRig(headColor: bark, torsoColor: bark, limbColor: darkBark)
        for sx in [-0.09, 0.0, 0.09] as [CGFloat] {
            let eye = vbox(0.06, 0.16, 0.02, .glow(1.0, 0.6, 0.1))
            eye.position = SCNVector3(sx, 0.05, 0.26)
            r.head.addChildNode(eye)
        }
        for sx in [-0.32, 0.32] as [CGFloat] {
            let branch = vbox(0.22, 0.08, 0.08, darkBark)
            branch.position = SCNVector3(sx, 0.10, 0)
            r.torso.addChildNode(branch)
        }
        let ice = vbox(0.55, 0.10, 0.40, .rgb(0.6, 0.9, 1.0))
        ice.position = SCNVector3(0, -0.85, 0)
        ice.isHidden = true
        r.torso.addChildNode(ice)
        self.ice = ice
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.ice?.isHidden = !self.isFrozen
            self.rig?.opacity = ACreakingWindow.isNight() ? 1.0 : 0.35
            self.rig?.walk(1.0 / 60.0)
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

// MARK: - 엔더마이트: 작게 기어다님 + 1타

public final class AEndermiteWindow: EntityWindow {
    public var position: CGPoint
    private let onTap: (AEndermiteWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private let panelW: CGFloat = 44
    private let panelH: CGFloat = 28

    public init(startPos: CGPoint, onTap: @escaping (AEndermiteWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let purple = VoxelColor.rgb(0.55, 0.3, 0.75)
        let r = QuadRig(bodyColor: purple, headColor: .rgb(0.5, 0.25, 0.7), legColor: .rgb(0.4, 0.2, 0.6), tailColor: nil)
        r.scale = SCNVector3(0.55, 0.55, 0.55)
        let eye = vbox(0.08, 0.08, 0.02, .glow(1.0, 0.2, 0.2))
        eye.position = SCNVector3(0.08, 0.05, 0.25)
        r.head.addChildNode(eye)
        let mote = vbox(0.08, 0.08, 0.08, .glow(0.7, 0.4, 1.0))
        mote.position = SCNVector3(-0.30, 0.25, 0)
        r.body.addChildNode(mote)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = self.dir > 0 ? CGFloat(Double.pi / 2.0) : CGFloat(-Double.pi / 2.0)
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
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private let panelW: CGFloat = 88
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping (ASkeletonHorseTrapWindow) -> Void) {
        self.position = startPos
        self.onTap = onTap
        super.init(contentRect: NSRect(x: startPos.x - panelW / 2, y: startPos.y, width: panelW, height: panelH), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        let bone = VoxelColor.rgb(0.88, 0.88, 0.88)
        let r = QuadRig(bodyColor: bone, headColor: bone, legColor: .rgb(0.82, 0.82, 0.82), tailColor: bone)
        for sx in [-0.12, -0.04, 0.04, 0.12] as [CGFloat] {
            let rib = vbox(0.04, 0.30, 0.52, .rgb(0.6, 0.6, 0.62))
            rib.position = SCNVector3(sx, 0.05, 0)
            r.body.addChildNode(rib)
        }
        let eye = vbox(0.07, 0.07, 0.02, VoxelColor.rgb(0.1, 0.1, 0.1))
        eye.position = SCNVector3(0.12, 0.05, 0.25)
        r.head.addChildNode(eye)
        let saddle = vbox(0.40, 0.08, 0.50, .rgb(0.5, 0.32, 0.2))
        saddle.position = SCNVector3(0, 0.30, -0.05)
        r.body.addChildNode(saddle)
        for sx in [-0.10, 0.10] as [CGFloat] {
            let riderBody = vbox(0.12, 0.16, 0.12, bone)
            riderBody.position = SCNVector3(sx, 0.44, -0.05)
            r.body.addChildNode(riderBody)
            let riderHead = vbox(0.12, 0.12, 0.12, bone)
            riderHead.position = SCNVector3(sx, 0.58, -0.05)
            r.body.addChildNode(riderHead)
        }
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in guard let self = self else { return }; self.onTap(self) }
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
            self.rig?.walk(1.0 / 60.0)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? CGFloat(Double.pi / 2.0) : CGFloat(-Double.pi / 2.0)
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    @discardableResult
    public func hit() -> Bool {
        let defeated = counter.hit()
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
