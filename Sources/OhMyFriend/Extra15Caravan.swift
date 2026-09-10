import AppKit
import CoreGraphics
import SceneKit

// 15차 백로그: 사막 캐러밴 5종(낙타·라마·행상인·선인장·사원함정) + CaravanManager.

private final class CaravanCamelWindow: EntityWindow {
    private var position: CGPoint
    private var riding = false
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var wander = WanderState(speed: 30.0)
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var saddle: SCNNode?
    private var rider: SCNNode?

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 84, height: 84)
        super.init(contentRect: NSRect(x: startPos.x - 42, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let tan = VoxelColor.rgb(0.76, 0.60, 0.42)
        let dark = VoxelColor.rgb(0.68, 0.52, 0.36)
        let r = QuadRig(bodyColor: tan, headColor: tan, legColor: dark)
        let hump = vbox(0.30, 0.26, 0.42, .rgb(0.70, 0.53, 0.36))
        hump.position = SCNVector3(0, 0.36, -0.05)
        r.body.addChildNode(hump)
        let neck = vbox(0.20, 0.55, 0.20, tan)
        neck.position = SCNVector3(0, 0.42, 0.08)
        r.head.addChildNode(neck)
        let skull = vbox(0.34, 0.24, 0.30, tan)
        skull.position = SCNVector3(0, 0.72, 0.12)
        r.head.addChildNode(skull)
        for x in [-0.12, 0.12] as [CGFloat] {
            let eye = vbox(0.05, 0.06, 0.02, .rgb(0.10, 0.10, 0.10))
            eye.position = SCNVector3(x, 0.74, 0.28)
            r.head.addChildNode(eye)
        }
        let sad = vbox(0.40, 0.10, 0.34, .rgb(0.75, 0.20, 0.20))
        sad.position = SCNVector3(0, 0.52, -0.05)
        sad.isHidden = true
        r.body.addChildNode(sad)
        let rid = vbox(0.16, 0.16, 0.16, .rgb(0.95, 0.80, 0.50))
        rid.position = SCNVector3(0, 0.65, -0.05)
        rid.isHidden = true
        r.body.addChildNode(rid)
        self.saddle = sad
        self.rider = rid
        r.addTo(view.scene!, scale: 1.15)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in self?.toggleRide() }
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.wander.speed = self.riding ? 60.0 : 30.0
            self.position.x += self.wander.tick(1.0 / 60.0)
            self.setFrameOrigin(NSPoint(x: self.position.x - 42, y: self.position.y))
            self.rig?.walk(1.0 / 60.0)
            let fast = self.riding ? 8.0 : 4.0
            if let r = self.rig {
                r.body.position.y += CGFloat(sin(self.phase * fast)) * 0.03
                r.eulerAngles.y = self.wander.direction > 0 ? 0 : CGFloat.pi
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func toggleRide() {
        riding.toggle()
        saddle?.isHidden = !riding
        rider?.isHidden = !riding
        if riding {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🐪 히야!")
            if RewardCenter.friendPos?() != nil {
                RewardCenter.say("👥 동승!")
            }
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    override func mouseDown(with event: NSEvent) {
        toggleRide()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class CaravanLlamaWindow: EntityWindow {
    private var position: CGPoint
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var wander = WanderState(speed: 26.0)
    private var spitCooldown = Cooldown()
    private var spitUntil: TimeInterval = 0
    private var sceneView: MobSceneView?
    private var rig: QuadRig?
    private var spitNodes: [SCNNode] = []

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 88, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - 44, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let cream = VoxelColor.rgb(0.87, 0.80, 0.70)
        let r = QuadRig(bodyColor: cream, headColor: cream, legColor: .rgb(0.78, 0.70, 0.60))
        let neck = vbox(0.18, 0.50, 0.18, cream)
        neck.position = SCNVector3(0, 0.35, 0.05)
        r.head.addChildNode(neck)
        let skull = vbox(0.30, 0.22, 0.26, cream)
        skull.position = SCNVector3(0, 0.62, 0.08)
        r.head.addChildNode(skull)
        for x in [-0.09, 0.09] as [CGFloat] {
            let ear = vbox(0.08, 0.16, 0.06, cream)
            ear.position = SCNVector3(x, 0.80, 0.05)
            r.head.addChildNode(ear)
        }
        let eye = vbox(0.05, 0.06, 0.02, .rgb(0.10, 0.10, 0.10))
        eye.position = SCNVector3(0.10, 0.64, 0.22)
        r.head.addChildNode(eye)
        let carpets: [VoxelColor] = [.rgb(0.80, 0.20, 0.20), .rgb(0.20, 0.35, 0.80), .rgb(0.25, 0.65, 0.30)]
        let carpet = vbox(0.56, 0.24, 0.42, carpets[Int.random(in: 0..<3)])
        carpet.position = SCNVector3(0, 0.12, 0)
        r.body.addChildNode(carpet)
        let spitSpots: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.0, 0.10, 0.50, 0.12), (0.10, 0.06, 0.70, 0.09), (0.20, 0.02, 0.90, 0.07)
        ]
        for (x, y, z, s) in spitSpots {
            let drop = vbox(s, s, s, .rgb(0.45, 0.75, 0.40))
            drop.position = SCNVector3(x, y, z)
            drop.isHidden = true
            r.head.addChildNode(drop)
            spitNodes.append(drop)
        }
        r.addTo(view.scene!, scale: 1.0)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in self?.pat() }
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        spitCooldown.trigger(6.0)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.position.x += self.wander.tick(1.0 / 60.0)
            self.setFrameOrigin(NSPoint(x: self.position.x - 44, y: self.position.y))
            self.spitCooldown.tick(1.0 / 60.0)
            if self.spitCooldown.ready {
                self.spitCooldown.trigger(TimeInterval.random(in: 8.0...15.0))
                self.spitUntil = self.phase + 1.0
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.say("💦 퉤!")
            }
            let spitting = self.phase < self.spitUntil
            for n in self.spitNodes { n.isHidden = !spitting }
            self.rig?.walk(1.0 / 60.0)
            if let r = self.rig {
                r.body.position.y += CGFloat(sin(self.phase * 4.0)) * 0.03
                r.eulerAngles.y = self.wander.direction > 0 ? 0 : CGFloat.pi
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func pat() {
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.grant(xp: 1, "❤️")
    }

    override func mouseDown(with event: NSEvent) {
        pat()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class CaravanTraderWindow: EntityWindow {
    private var position: CGPoint
    private var timer: Timer?
    private var phase: TimeInterval = 0
    private var traded = false
    private var sceneView: MobSceneView?
    private var rig: BipedRig?

    init(startPos: CGPoint) {
        self.position = startPos
        let size = NSSize(width: 76, height: 68)
        super.init(contentRect: NSRect(x: startPos.x - 38, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let robe = VoxelColor.rgb(0.30, 0.35, 0.80)
        let robeDark = VoxelColor.rgb(0.20, 0.25, 0.60)
        let r = BipedRig(headColor: .rgb(0.90, 0.75, 0.60), torsoColor: robe, limbColor: robeDark)
        for x in [-0.09, 0.09] as [CGFloat] {
            let eye = vbox(0.06, 0.07, 0.02, .rgb(0.10, 0.10, 0.10))
            eye.position = SCNVector3(x, 0.06, 0.26)
            r.head.addChildNode(eye)
        }
        let brim = vbox(0.56, 0.08, 0.56, .rgb(0.45, 0.25, 0.15))
        brim.position = SCNVector3(0, 0.28, 0)
        r.head.addChildNode(brim)
        let cap = vbox(0.34, 0.14, 0.34, .rgb(0.45, 0.25, 0.15))
        cap.position = SCNVector3(0, 0.38, 0)
        r.head.addChildNode(cap)
        let bag = vbox(0.16, 0.28, 0.12, .rgb(0.55, 0.38, 0.22))
        bag.position = SCNVector3(0.26, -0.10, 0)
        r.torso.addChildNode(bag)
        let llamaCream = VoxelColor.rgb(0.87, 0.80, 0.70)
        let miniBody = vbox(0.24, 0.18, 0.16, llamaCream)
        miniBody.position = SCNVector3(-0.30, -0.15, 0.10)
        r.torso.addChildNode(miniBody)
        let miniNeck = vbox(0.08, 0.20, 0.08, llamaCream)
        miniNeck.position = SCNVector3(-0.24, 0.02, 0.14)
        r.torso.addChildNode(miniNeck)
        let miniHead = vbox(0.12, 0.10, 0.12, llamaCream)
        miniHead.position = SCNVector3(-0.24, 0.15, 0.16)
        r.torso.addChildNode(miniHead)
        r.addTo(view.scene!, scale: 0.8)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in self?.showTradeAlert() }
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.rig?.position.y = CGFloat(sin(self.phase * 3.0)) * 0.05
        }
        RunLoop.main.add(timer!, forMode: .common)
        // 50% 확률로 귀가
        if Bool.random() {
            RewardCenter.say("🧳 오늘은 장사 안 해!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.close()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showTradeAlert()
            }
        }
    }

    private func showTradeAlert() {
        guard isVisible else { return }
        let alert = NSAlert()
        alert.messageText = "🧳 행상인"
        alert.informativeText = "이국적인 물건을 가져왔네! 하나 골라보게."
        alert.addButton(withTitle: "발광열매")
        alert.addButton(withTitle: "안장")
        alert.addButton(withTitle: "화살통")
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn || resp == .alertSecondButtonReturn || resp == .alertThirdButtonReturn {
            if !traded {
                traded = true
                SoundAndEffectsManager.shared.play(.pop)
                RewardCenter.grant(xp: 3, "🤑 득템!")
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        showTradeAlert()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class CaravanCactusWindow: EntityWindow {
    private var sceneView: MobSceneView?
    private var rig: CubeRig?

    init(startPos: CGPoint) {
        let size = NSSize(width: 60, height: 58)
        super.init(contentRect: NSRect(x: startPos.x - 30, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let r = CubeRig(color: .rgb(0.25, 0.65, 0.30), size: 0.85)
        let pot = vbox(0.70, 0.22, 0.70, .rgb(0.65, 0.35, 0.20))
        pot.position = SCNVector3(0, 0.11, 0)
        r.addChildNode(pot)
        r.addTo(view.scene!, scale: 1.0)
        view.setSubject(r)
        self.rig = r
        self.sceneView = view
        view.onTap = { [weak self] in self?.poke() }
        contentView = view
    }

    func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    private func poke() {
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🌵 따끔!")
    }

    override func mouseDown(with event: NSEvent) {
        poke()
    }
}

// MARK: - 사원 함정

private final class CaravanTempleDrawView: NSView {
    var fuseBlink = false
    var exploded = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if exploded {
            ctx.setFillColor(red: 1.0, green: 0.95, blue: 0.70, alpha: 0.95)
            ctx.fillEllipse(in: CGRect(x: 8, y: 4, width: 84, height: 60))
            ctx.setFillColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 24, y: 14, width: 52, height: 38))
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 0.40, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 40, y: 24, width: 20, height: 18))
            return
        }
        // 사막 사원 입구
        ctx.setFillColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 18, width: 88, height: 40))
        ctx.setFillColor(red: 0.75, green: 0.63, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: 6, y: 52, width: 88, height: 8))
        // 입구
        ctx.setFillColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        ctx.fill(CGRect(x: 38, y: 18, width: 24, height: 30))
        // 압력판
        if fuseBlink {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.70, green: 0.55, blue: 0.35, alpha: 1.0)
        }
        ctx.fill(CGRect(x: 40, y: 6, width: 20, height: 8))
        // 황금 장식
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 44, width: 8, height: 8))
        ctx.fill(CGRect(x: 78, y: 44, width: 8, height: 8))
    }
}

private final class CaravanTempleWindow: EntityWindow {
    private var fuseTimer: Timer?
    private var fuseElapsed: TimeInterval = 0
    private var used = false
    private var drawView: CaravanTempleDrawView?

    init(startPos: CGPoint) {
        let size = NSSize(width: 100, height: 64)
        super.init(contentRect: NSRect(x: startPos.x - 50, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = CaravanTempleDrawView(frame: NSRect(origin: .zero, size: size))
        self.drawView = view
        contentView = view
    }

    func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    override func mouseDown(with event: NSEvent) {
        guard !used else { return }
        used = true
        fuseElapsed = 0
        SoundAndEffectsManager.shared.play(.pop)
        fuseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.fuseElapsed += 0.15
            self.drawView?.fuseBlink.toggle()
            self.drawView?.needsDisplay = true
            if self.fuseElapsed >= 2.0 {
                t.invalidate()
                self.fuseTimer = nil
                self.explode()
            }
        }
        RunLoop.main.add(fuseTimer!, forMode: .common)
    }

    private func explode() {
        drawView?.exploded = true
        drawView?.needsDisplay = true
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("💥 펑!")
        RewardCenter.grant(xp: 6, "🏺 황금 보상!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.close()
        }
    }

    override func close() {
        fuseTimer?.invalidate()
        fuseTimer = nil
        super.close()
    }
}

// MARK: - CaravanManager

public final class CaravanManager {
    public static let shared = CaravanManager()
    private init() {}

    private var camel: CaravanCamelWindow?
    private var llama: CaravanLlamaWindow?
    private var trader: CaravanTraderWindow?
    private var cacti: [CaravanCactusWindow] = []
    private var temple: CaravanTempleWindow?

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🐪 낙타 타기" }, { [weak self] in self?.spawnCamel() }),
            ExtraMenuEntry({ "🦙 라마 쓰다듬기" }, { [weak self] in self?.spawnLlama() }),
            ExtraMenuEntry({ "🧳 행상인 거래" }, { [weak self] in self?.spawnTrader() }),
            ExtraMenuEntry({ "🌵 선인장 화분" }, { [weak self] in self?.placeCactus() }),
            ExtraMenuEntry({ "🏺 사원 발굴" }, { [weak self] in self?.spawnTemple() }),
        ]
    }

    private func spawnCamel() {
        camel?.close()
        let base = RewardCenter.me()
        let w = CaravanCamelWindow(startPos: CGPoint(x: base.x + 120, y: base.y))
        camel = w
        w.start()
    }

    private func spawnLlama() {
        llama?.close()
        let base = RewardCenter.me()
        let w = CaravanLlamaWindow(startPos: CGPoint(x: base.x - 120, y: base.y))
        llama = w
        w.start()
    }

    private func spawnTrader() {
        trader?.close()
        let base = RewardCenter.me()
        let w = CaravanTraderWindow(startPos: CGPoint(x: base.x + 60, y: base.y + 40))
        trader = w
        w.start()
    }

    private func placeCactus() {
        let base = RewardCenter.me()
        let offset = CGFloat(cacti.count * 56)
        let w = CaravanCactusWindow(startPos: CGPoint(x: base.x - 80 - offset, y: base.y))
        w.place()
        cacti.append(w)
        while cacti.count > 3 {
            let old = cacti.removeFirst()
            old.close()
        }
    }

    private func spawnTemple() {
        temple?.close()
        let base = RewardCenter.me()
        let w = CaravanTempleWindow(startPos: CGPoint(x: base.x, y: base.y + 80))
        temple = w
        w.start()
    }
}
