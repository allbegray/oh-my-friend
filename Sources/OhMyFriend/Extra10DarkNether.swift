import AppKit
import CoreGraphics
import Foundation
import SceneKit

// 10차 백로그: 다크 네더 5종(위더스켈레톤·블레이즈·익사자·브리즈·실버피시).
// GhastWindow 화염탄 미니 패널 패턴을 투사체 3종에 재사용한다.

// MARK: - 위더 디버프 토스트 (플레이어 머리 위 🖤 20초)

public final class WitherDebuffToastWindow: EntityWindow {
    private var lifeTimer: Timer?

    public init(above pos: CGPoint) {
        let size = NSSize(width: 92, height: 36)
        super.init(contentRect: NSRect(x: pos.x - 46, y: pos.y + 70, width: size.width, height: size.height), ignoresMouse: true)
        contentView = WitherDebuffDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.alert)
        lifeTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
            self?.close()
        }
        if let t = lifeTimer { RunLoop.main.add(t, forMode: .common) }
    }

    public override func close() {
        lifeTimer?.invalidate()
        lifeTimer = nil
        super.close()
    }
}

private final class WitherDebuffDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.88)
        let r = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        ctx.fillEllipse(in: r)
        let s = "🖤 시듦!" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15)]
        let sz = s.size(withAttributes: attrs)
        s.draw(at: CGPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2), withAttributes: attrs)
    }
}

// MARK: - 위더스켈레톤 (검은 갑주 검사 + 접근 시 🖤 디버프, 클릭 2타 석탄 +3XP)

public final class WitherSkeletonWindow: EntityWindow {
    public private(set) var position: CGPoint
    private var hits = HitCounter(maxHits: 2)
    private var phase: TimeInterval = 0
    private var wander = WanderState(speed: 34)
    private var debuffGate = Cooldown()
    private var walkTimer: Timer?
    private let onDefeat: () -> Void
    private let onProximity: () -> Void
    private var rig: BipedRig?
    private var isGone = false

    public init(startPos: CGPoint, onDefeat: @escaping () -> Void, onProximity: @escaping () -> Void) {
        self.position = startPos
        self.onDefeat = onDefeat
        self.onProximity = onProximity
        let size = NSSize(width: 64, height: 84)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = BipedRig(headColor: .rgb(0.15, 0.15, 0.16), torsoColor: .rgb(0.12, 0.12, 0.14), limbColor: .rgb(0.10, 0.10, 0.11))
        let trim = vbox(0.38, 0.08, 0.24, .rgb(0.35, 0.35, 0.38))
        trim.position = SCNVector3(0, 0.28, 0)
        rig.torso.addChildNode(trim)
        for sx in [-0.32, 0.32] as [CGFloat] {
            let skull = vbox(0.30, 0.30, 0.30, .rgb(0.15, 0.15, 0.16))
            skull.position = SCNVector3(sx, 0.10, 0)
            rig.head.addChildNode(skull)
            for ex in [-0.07, 0.07] as [CGFloat] {
                let eye = vbox(0.06, 0.07, 0.02, .glow(1.0, 1.0, 1.0))
                eye.position = SCNVector3(sx + ex, 0.12, 0.16)
                rig.head.addChildNode(eye)
            }
        }
        for ex in [-0.10, 0.10] as [CGFloat] {
            let eye = vbox(0.08, 0.09, 0.02, .glow(1.0, 1.0, 1.0))
            eye.position = SCNVector3(ex, 0.05, 0.26)
            rig.head.addChildNode(eye)
        }
        let blade = vbox(0.09, 0.70, 0.04, .rgb(0.55, 0.55, 0.58))
        blade.position = SCNVector3(0, -0.75, 0)
        rig.armR.addChildNode(blade)
        let grip = vbox(0.16, 0.07, 0.07, .rgb(0.30, 0.20, 0.12))
        grip.position = SCNVector3(0, -0.42, 0)
        rig.armR.addChildNode(grip)
        rig.scale = SCNVector3(0.6, 0.6, 0.6)
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.handleTap()
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.phase += dt
            self.debuffGate.tick(dt)
            self.position.x += self.wander.tick(dt)
            self.setFrameOrigin(NSPoint(x: self.position.x - 32, y: self.position.y))
            let me = RewardCenter.me()
            if self.debuffGate.ready && hypot(me.x - self.position.x, me.y - self.position.y) < 140 {
                self.debuffGate.trigger(20.0)
                self.onProximity()
            }
            self.rig?.walk(dt)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? 0 : CGFloat.pi
            self.rig?.position.y = sin(self.phase * 5.0) * 0.03
        }
        RunLoop.main.add(walkTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }

    private func handleTap() {
        if hits.hit() {
            disappear(defeated: true)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("💀 쾅!")
        }
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        walkTimer?.invalidate()
        walkTimer = nil
        if defeated { onDefeat() }
        close()
    }

    public override func close() {
        walkTimer?.invalidate()
        walkTimer = nil
        super.close()
    }
}

private final class WitherSkeletonDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 검은 갑주 몸통
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 28 + bob, width: 20, height: 26))
        // 갑주 테두리 (회색)
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 22, y: 50 + bob, width: 20, height: 4))
        // 해골 머리
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 56 + bob, width: 24, height: 20))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 25, y: 64 + bob, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: 34, y: 64 + bob, width: 5, height: 6))
        // 석검
        ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
        ctx.fill(CGRect(x: 46, y: 24 + bob, width: 6, height: 30))
        ctx.setFillColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: 44, y: 20 + bob, width: 10, height: 5))
        // 다리
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0)
        ctx.fill(CGRect(x: 24, y: 6, width: 7, height: 22))
        ctx.fill(CGRect(x: 33, y: 6, width: 7, height: 22))
        ctx.restoreGState()
    }
}

// MARK: - 블레이즈 (공중 부유+회전 막대, 화염탄, 클릭 2타 막대 +4XP)

public final class BlazeWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var hits = HitCounter(maxHits: 2)
    private var phase: TimeInterval = 0
    private var shootGate = Cooldown()
    private var flyTimer: Timer?
    private let onShoot: (CGPoint) -> Void
    private let onDefeat: () -> Void
    private var rig: FlyerRig?
    private var rodsNode: SCNNode?
    private var isGone = false

    public init(startPos: CGPoint, onShoot: @escaping (CGPoint) -> Void, onDefeat: @escaping () -> Void) {
        self.anchor = startPos
        self.onShoot = onShoot
        self.onDefeat = onDefeat
        let size = NSSize(width: 72, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - 36, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(bodyColor: .rgb(1.0, 0.85, 0.20), wingColor: .rgb(1.0, 0.75, 0.15))
        let rods = SCNNode()
        for i in 0..<4 {
            let a = CGFloat(i) * .pi / 2
            let rod = vbox(0.10, 0.42, 0.10, .rgb(1.0, 0.75, 0.15))
            rod.position = SCNVector3(Float(cos(a) * 0.42), -0.05, Float(sin(a) * 0.42))
            rods.addChildNode(rod)
        }
        rig.body.addChildNode(rods)
        self.rodsNode = rods
        for ex in [-0.08, 0.08] as [CGFloat] {
            let eye = vbox(0.07, 0.08, 0.02, .rgb(0.15, 0.10, 0.05))
            eye.position = SCNVector3(ex, 0.08, 0.17)
            rig.body.addChildNode(eye)
        }
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.handleTap()
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        shootGate.trigger(5.0)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.phase += dt
            self.shootGate.tick(dt)
            let cx = self.anchor.x + sin(self.phase * 0.8) * 70.0
            let cy = self.anchor.y + 90 + sin(self.phase * 1.3) * 18.0
            self.setFrameOrigin(NSPoint(x: cx - 36, y: cy))
            self.rig?.flap(dt)
            self.rodsNode?.eulerAngles.y = self.phase * 2.4
            if self.shootGate.ready {
                self.shootGate.trigger(Double.random(in: 4.0...6.0))
                self.onShoot(CGPoint(x: cx, y: cy))
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public var centerPos: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }

    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }

    private func handleTap() {
        if hits.hit() {
            disappear(defeated: true)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        flyTimer?.invalidate()
        flyTimer = nil
        if defeated { onDefeat() }
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class BlazeDrawView: NSView {
    var spin: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        let cy = bounds.height / 2
        // 회전 막대 4개
        for i in 0..<4 {
            let a = spin + CGFloat(i) * .pi / 2
            let x = cx + cos(a) * 20 - 3
            let y = cy + sin(a) * 20 - 8
            ctx.setFillColor(red: 1.0, green: 0.75, blue: 0.15, alpha: 1.0)
            ctx.fill(CGRect(x: x, y: y, width: 6, height: 16))
        }
        // 머리 코어
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 12, y: cy - 12, width: 24, height: 24))
        ctx.setFillColor(red: 0.15, green: 0.10, blue: 0.05, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 7, y: cy + 1, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: cx + 2, y: cy + 1, width: 5, height: 6))
    }
}

// 블레이즈 화염탄 미니 패널 (클릭 쳐내기 격추)

public final class DarkFireballWindow: EntityWindow {
    private let from: CGPoint
    private let target: CGPoint
    private let onArrive: (Bool) -> Void
    private var flyTimer: Timer?

    public init(from: CGPoint, target: CGPoint, onArrive: @escaping (Bool) -> Void) {
        self.from = from
        self.target = target
        self.onArrive = onArrive
        let size: CGFloat = 30.0
        super.init(contentRect: NSRect(x: from.x - 15, y: from.y - 15, width: size, height: size), ignoresMouse: false)
        contentView = DarkFireballDrawView(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
    }

    public func launch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        let distance = hypot(target.x - from.x, target.y - from.y)
        let flightTime = max(0.5, Double(distance / 420.0))
        let startTime = ProcessInfo.processInfo.systemUptime
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let p = min(1.0, CGFloat(elapsed / flightTime))
            let curX = self.from.x + (self.target.x - self.from.x) * p
            let curY = self.from.y + (self.target.y - self.from.y) * p
            self.setFrameOrigin(NSPoint(x: curX - 15, y: curY - 15))
            if p >= 1.0 {
                t.invalidate()
                self.flyTimer = nil
                self.onArrive(true)
                self.close()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        flyTimer?.invalidate()
        flyTimer = nil
        onArrive(false)
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class DarkFireballDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = bounds.width
        ctx.setFillColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: s - 4, height: s - 4))
        ctx.setFillColor(red: 1.0, green: 0.90, blue: 0.30, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: s - 16, height: s - 16))
    }
}

// MARK: - 익사자 (지상 보행 + 3초 간격 미니 삼지창, 클릭 2타 파편 +4XP)

public final class DrownedWindow: EntityWindow {
    public private(set) var position: CGPoint
    private var hits = HitCounter(maxHits: 2)
    private var phase: TimeInterval = 0
    private var wander = WanderState(speed: 26)
    private var throwGate = Cooldown()
    private var walkTimer: Timer?
    private let onThrow: (CGPoint) -> Void
    private let onDefeat: () -> Void
    private var rig: BipedRig?
    private var isGone = false

    public init(startPos: CGPoint, onThrow: @escaping (CGPoint) -> Void, onDefeat: @escaping () -> Void) {
        self.position = startPos
        self.onThrow = onThrow
        self.onDefeat = onDefeat
        let size = NSSize(width: 60, height: 72)
        super.init(contentRect: NSRect(x: startPos.x - 30, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = BipedRig(headColor: .rgb(0.35, 0.70, 0.65), torsoColor: .rgb(0.20, 0.55, 0.55), limbColor: .rgb(0.18, 0.45, 0.48))
        for ex in [-0.10, 0.10] as [CGFloat] {
            let eye = vbox(0.08, 0.09, 0.02, .rgb(0.05, 0.10, 0.12))
            eye.position = SCNVector3(ex, 0.05, 0.26)
            rig.head.addChildNode(eye)
        }
        let shaft = vbox(0.05, 0.85, 0.05, .rgb(0.55, 0.75, 0.80))
        shaft.position = SCNVector3(0, -0.80, 0)
        rig.armR.addChildNode(shaft)
        let bar = vbox(0.24, 0.05, 0.05, .rgb(0.55, 0.75, 0.80))
        bar.position = SCNVector3(0, -0.40, 0)
        rig.armR.addChildNode(bar)
        for sx in [-0.10, 0, 0.10] as [CGFloat] {
            let prong = vbox(0.05, 0.18, 0.05, .rgb(0.55, 0.80, 0.85))
            prong.position = SCNVector3(sx, -0.28, 0)
            rig.armR.addChildNode(prong)
        }
        rig.scale = SCNVector3(0.6, 0.6, 0.6)
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.handleTap()
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        throwGate.trigger(3.0)
        walkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.phase += dt
            self.throwGate.tick(dt)
            self.position.x += self.wander.tick(dt)
            self.setFrameOrigin(NSPoint(x: self.position.x - 30, y: self.position.y))
            self.rig?.walk(dt)
            self.rig?.eulerAngles.y = self.wander.direction > 0 ? 0 : CGFloat.pi
            self.rig?.position.y = sin(self.phase * 4.0) * 0.03
            if self.throwGate.ready {
                self.throwGate.trigger(3.0)
                self.onThrow(CGPoint(x: self.position.x, y: self.position.y + 44))
            }
        }
        RunLoop.main.add(walkTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }

    private func handleTap() {
        if hits.hit() {
            disappear(defeated: true)
        } else {
            SoundAndEffectsManager.shared.play(.splash)
        }
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        walkTimer?.invalidate()
        walkTimer = nil
        if defeated { onDefeat() }
        close()
    }

    public override func close() {
        walkTimer?.invalidate()
        walkTimer = nil
        super.close()
    }
}

private final class DrownedDrawView: NSView {
    var facingRight = true
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 청록 좀비 몸
        ctx.setFillColor(red: 0.20, green: 0.55, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: 18, y: 24 + bob, width: 20, height: 24))
        ctx.setFillColor(red: 0.35, green: 0.70, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 50 + bob, width: 24, height: 16))
        ctx.setFillColor(red: 0.05, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 22, y: 56 + bob, width: 5, height: 6))
        ctx.fillEllipse(in: CGRect(x: 31, y: 56 + bob, width: 5, height: 6))
        // 미니 삼지창
        ctx.setFillColor(red: 0.55, green: 0.75, blue: 0.80, alpha: 1.0)
        ctx.fill(CGRect(x: 42, y: 18 + bob, width: 3, height: 40))
        ctx.fill(CGRect(x: 38, y: 54 + bob, width: 11, height: 3))
        // 다리
        ctx.setFillColor(red: 0.18, green: 0.45, blue: 0.48, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 4, width: 7, height: 20))
        ctx.fill(CGRect(x: 29, y: 4, width: 7, height: 20))
        ctx.restoreGState()
    }
}

// 익사자 미니 삼지창 투척체 (맞으면 넉백 emoji)

public final class MiniTridentWindow: EntityWindow {
    private let from: CGPoint
    private let target: CGPoint
    private let onArrive: (Bool) -> Void
    private var flyTimer: Timer?

    public init(from: CGPoint, target: CGPoint, onArrive: @escaping (Bool) -> Void) {
        self.from = from
        self.target = target
        self.onArrive = onArrive
        let size = NSSize(width: 32, height: 32)
        super.init(contentRect: NSRect(x: from.x - 16, y: from.y - 16, width: size.width, height: size.height), ignoresMouse: false)
        contentView = MiniTridentDrawView(frame: NSRect(origin: .zero, size: size))
    }

    public func launch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        let distance = hypot(target.x - from.x, target.y - from.y)
        let flightTime = max(0.5, Double(distance / 460.0))
        let startTime = ProcessInfo.processInfo.systemUptime
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let p = min(1.0, CGFloat(elapsed / flightTime))
            let curX = self.from.x + (self.target.x - self.from.x) * p
            let curY = self.from.y + (self.target.y - self.from.y) * p
            self.setFrameOrigin(NSPoint(x: curX - 16, y: curY - 16))
            if p >= 1.0 {
                t.invalidate()
                self.flyTimer = nil
                self.onArrive(true)
                self.close()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        flyTimer?.invalidate()
        flyTimer = nil
        onArrive(false)
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class MiniTridentDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.55, green: 0.80, blue: 0.85, alpha: 1.0)
        ctx.fill(CGRect(x: 14, y: 2, width: 4, height: 24))
        ctx.fill(CGRect(x: 8, y: 22, width: 16, height: 3))
        ctx.fill(CGRect(x: 8, y: 22, width: 3, height: 8))
        ctx.fill(CGRect(x: 14, y: 22, width: 3, height: 8))
        ctx.fill(CGRect(x: 21, y: 22, width: 3, height: 8))
    }
}

// MARK: - 브리즈 (공중 지그재그 콤보 + 바람탄 테니스 반사 즉사 +5XP / 직격 넉백)

public final class BreezeWindow: EntityWindow {
    public var anchor: CGPoint = .zero
    private var phase: TimeInterval = 0
    private var shootGate = Cooldown()
    private var flyTimer: Timer?
    private let onShoot: (CGPoint) -> Void
    private let onLeave: () -> Void
    private var rig: FlyerRig?
    private var swirlNode: SCNNode?
    private var isGone = false

    public init(startPos: CGPoint, onShoot: @escaping (CGPoint) -> Void, onLeave: @escaping () -> Void) {
        self.anchor = startPos
        self.onShoot = onShoot
        self.onLeave = onLeave
        let size = NSSize(width: 64, height: 64)
        super.init(contentRect: NSRect(x: startPos.x - 32, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = FlyerRig(bodyColor: .rgb(0.90, 0.97, 1.0), wingColor: .rgb(0.65, 0.85, 0.95))
        let swirl = SCNNode()
        for i in 0..<3 {
            let a = CGFloat(i) * 2.1
            let seg = vbox(0.10, 0.30, 0.10, .rgb(0.65, 0.85, 0.95))
            seg.position = SCNVector3(Float(cos(a) * 0.38), 0, Float(sin(a) * 0.38))
            seg.eulerAngles.y = a
            swirl.addChildNode(seg)
        }
        rig.body.addChildNode(swirl)
        self.swirlNode = swirl
        for ex in [-0.08, 0.08] as [CGFloat] {
            let eye = vbox(0.06, 0.08, 0.02, .rgb(0.20, 0.30, 0.45))
            eye.position = SCNVector3(ex, 0.05, 0.17)
            rig.body.addChildNode(eye)
        }
        view.setSubject(rig)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.handleTap()
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        shootGate.trigger(4.0)
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.phase += dt
            self.shootGate.tick(dt)
            let cx = self.anchor.x + sin(self.phase * 1.7) * 110.0
            let cy = self.anchor.y + 100 + abs(sin(self.phase * 2.3)) * 50.0
            self.setFrameOrigin(NSPoint(x: cx - 32, y: cy))
            self.rig?.flap(dt)
            self.swirlNode?.eulerAngles.y = CGFloat(self.phase * 3.0)
            if self.shootGate.ready {
                self.shootGate.trigger(Double.random(in: 3.5...5.0))
                self.onShoot(CGPoint(x: cx, y: cy))
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public var centerPos: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }

    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }

    private func handleTap() {
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🌀 바람이라 안 맞아!")
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        flyTimer?.invalidate()
        flyTimer = nil
        if !defeated { onLeave() }
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class BreezeDrawView: NSView {
    var spin: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        let cy = bounds.height / 2
        // 바람 소용돌이 링
        for i in 0..<3 {
            let r: CGFloat = 10 + CGFloat(i) * 7
            ctx.setStrokeColor(red: 0.65, green: 0.85, blue: 0.95, alpha: 0.9)
            ctx.setLineWidth(3)
            ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: spin + CGFloat(i), endAngle: spin + CGFloat(i) + 4.2, clockwise: false)
            ctx.strokePath()
        }
        // 코어 눈
        ctx.setFillColor(red: 0.90, green: 0.97, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14))
        ctx.setFillColor(red: 0.20, green: 0.30, blue: 0.45, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: cy - 1, width: 3, height: 4))
        ctx.fillEllipse(in: CGRect(x: cx + 1, y: cy - 1, width: 3, height: 4))
    }
}

// 브리즈 바람탄 (클릭 테니스 반사)

public final class WindChargeWindow: EntityWindow {
    private let from: CGPoint
    private let target: CGPoint
    private let onArrive: (Bool) -> Void
    private var flyTimer: Timer?

    public init(from: CGPoint, target: CGPoint, onArrive: @escaping (Bool) -> Void) {
        self.from = from
        self.target = target
        self.onArrive = onArrive
        let size: CGFloat = 30.0
        super.init(contentRect: NSRect(x: from.x - 15, y: from.y - 15, width: size, height: size), ignoresMouse: false)
        contentView = WindChargeDrawView(frame: NSRect(origin: .zero, size: NSSize(width: size, height: size)))
    }

    public func launch() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        let distance = hypot(target.x - from.x, target.y - from.y)
        let flightTime = max(0.5, Double(distance / 400.0))
        let startTime = ProcessInfo.processInfo.systemUptime
        flyTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let p = min(1.0, CGFloat(elapsed / flightTime))
            let curX = self.from.x + (self.target.x - self.from.x) * p
            let curY = self.from.y + (self.target.y - self.from.y) * p
            self.setFrameOrigin(NSPoint(x: curX - 15, y: curY - 15))
            if p >= 1.0 {
                t.invalidate()
                self.flyTimer = nil
                self.onArrive(true)
                self.close()
            }
        }
        RunLoop.main.add(flyTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        flyTimer?.invalidate()
        flyTimer = nil
        onArrive(false)
        close()
    }

    public override func close() {
        flyTimer?.invalidate()
        flyTimer = nil
        super.close()
    }
}

private final class WindChargeDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let s = bounds.width
        ctx.setFillColor(red: 0.80, green: 0.93, blue: 1.0, alpha: 0.95)
        ctx.fillEllipse(in: CGRect(x: 3, y: 3, width: s - 6, height: s - 6))
        ctx.setStrokeColor(red: 0.45, green: 0.70, blue: 0.90, alpha: 1.0)
        ctx.setLineWidth(2.5)
        ctx.addArc(center: CGPoint(x: s / 2, y: s / 2), radius: 7, startAngle: 0.4, endAngle: 4.6, clockwise: false)
        ctx.strokePath()
    }
}

// MARK: - 실버피시 (바닥 파고들기 숨기/랜덤 출몰, 출몰 클릭 1타 +1XP)

public final class SilverfishWindow: EntityWindow {
    public private(set) var position: CGPoint
    public private(set) var emerged: Bool = true
    private var phase: TimeInterval = 0
    private var emergeGate = Cooldown()
    private var crawlTimer: Timer?
    private let onDefeat: () -> Void
    private var rig: QuadRig?
    private var moundNode: SCNNode?
    private var isGone = false

    public init(startPos: CGPoint, onDefeat: @escaping () -> Void) {
        self.position = startPos
        self.onDefeat = onDefeat
        let size = NSSize(width: 48, height: 32)
        super.init(contentRect: NSRect(x: startPos.x - 24, y: startPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let view = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let rig = QuadRig(bodyColor: .rgb(0.70, 0.70, 0.72), headColor: .rgb(0.70, 0.70, 0.72), legColor: .rgb(0.55, 0.55, 0.58), tailColor: nil)
        for sx in [-0.12, 0, 0.12] as [CGFloat] {
            let stripe = vbox(0.05, 0.52, 0.60, .rgb(0.55, 0.55, 0.58))
            stripe.position = SCNVector3(sx, 0.02, -0.05)
            rig.body.addChildNode(stripe)
        }
        let eye = vbox(0.06, 0.06, 0.02, .rgb(0.10, 0.10, 0.10))
        eye.position = SCNVector3(0.12, 0.05, 0.25)
        rig.head.addChildNode(eye)
        rig.scale = SCNVector3(0.7, 0.7, 0.7)
        let mound = vbox(0.95, 0.32, 0.70, .rgb(0.45, 0.33, 0.22))
        mound.position = SCNVector3(0, 0.16, 0)
        mound.isHidden = true
        self.moundNode = mound
        let subject = SCNNode()
        subject.addChildNode(rig)
        subject.addChildNode(mound)
        view.setSubject(subject)
        self.rig = rig
        view.onTap = { [weak self] in
            guard let self = self else { return }
            self.handleTap()
        }
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        emergeGate.trigger(4.0)
        crawlTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let dt = 1.0 / 60.0
            self.phase += dt
            self.emergeGate.tick(dt)
            if self.emerged {
                self.position.x += sin(self.phase * 6.0) * 24.0 / 60.0
                self.setFrameOrigin(NSPoint(x: self.position.x - 24, y: self.position.y))
                self.rig?.walk(dt)
            }
            if self.emergeGate.ready {
                self.emerged.toggle()
                self.emergeGate.trigger(Double.random(in: 3.0...6.0))
                SoundAndEffectsManager.shared.play(.pop)
            }
            self.rig?.isHidden = !self.emerged
            self.moundNode?.isHidden = self.emerged
        }
        RunLoop.main.add(crawlTimer!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        handleTap()
    }

    private func handleTap() {
        guard emerged else { return }
        disappear(defeated: true)
    }

    public func disappear(defeated: Bool) {
        guard !isGone else { return }
        isGone = true
        crawlTimer?.invalidate()
        crawlTimer = nil
        if defeated { onDefeat() }
        close()
    }

    public override func close() {
        crawlTimer?.invalidate()
        crawlTimer = nil
        super.close()
    }
}

private final class SilverfishDrawView: NSView {
    var emerged = true
    var wiggle: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if !emerged {
            // 파고든 흙더미
            ctx.setFillColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 8, y: 2, width: 32, height: 16))
            ctx.setFillColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 14, y: 8, width: 20, height: 10))
            return
        }
        ctx.saveGState()
        ctx.translateBy(x: 24, y: 16)
        ctx.rotate(by: wiggle * 0.12)
        ctx.translateBy(x: -24, y: -16)
        ctx.setFillColor(red: 0.70, green: 0.70, blue: 0.72, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 10, width: 32, height: 12))
        ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
        for x in [14, 20, 26, 32] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 10, width: 2, height: 12))
        }
        ctx.setFillColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 35, y: 14, width: 3, height: 3))
        ctx.restoreGState()
    }
}

// MARK: - DarkNetherManager (메뉴 진입점, 스폰/해제 토글)

public final class DarkNetherManager {
    public static let shared = DarkNetherManager()

    private var wither: WitherSkeletonWindow?
    private var blaze: BlazeWindow?
    private var drowned: DrownedWindow?
    private var breeze: BreezeWindow?
    private var silverfish: SilverfishWindow?
    private var debuffToast: WitherDebuffToastWindow?
    private var shots: [NSPanel] = []

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "💀 위더 소환" }, { [weak self] in self?.toggleWither() }),
            ExtraMenuEntry({ "🔥 블레이즈 소환" }, { [weak self] in self?.toggleBlaze() }),
            ExtraMenuEntry({ "🧟‍♂️ 익사자 소환" }, { [weak self] in self?.toggleDrowned() }),
            ExtraMenuEntry({ "🌀 브리즈 소환" }, { [weak self] in self?.toggleBreeze() }),
            ExtraMenuEntry({ "🪨 실버피시 소환" }, { [weak self] in self?.toggleSilverfish() }),
        ]
    }

    private func spawnBase() -> CGPoint {
        let me = RewardCenter.me()
        if me == .zero { return CGPoint(x: 600, y: 300) }
        return CGPoint(x: me.x + 140, y: me.y)
    }

    private func trackShot(_ panel: NSPanel) {
        shots.append(panel)
    }

    private func dropShot(_ panel: NSPanel) {
        shots.removeAll { $0 === panel }
    }

    private func knockPlayer(dx: CGFloat) {
        let me = RewardCenter.me()
        guard me != .zero else { return }
        RewardCenter.movePlayer?(CGPoint(x: me.x + dx, y: me.y))
    }

    // -- 위더스켈레톤

    private func toggleWither() {
        if let w = wither {
            w.disappear(defeated: false)
            wither = nil
            RewardCenter.say("💀 위더 해제!")
            return
        }
        let pos = spawnBase()
        let w = WitherSkeletonWindow(startPos: pos, onDefeat: { [weak self] in
            RewardCenter.grant(xp: 3, "⬛ 석탄!")
            RewardCenter.say("💀 위더 격퇴!")
            SoundAndEffectsManager.shared.play(.pop)
            self?.wither = nil
        }, onProximity: { [weak self] in
            self?.showWitherDebuff()
        })
        wither = w
        w.start()
    }

    private func showWitherDebuff() {
        debuffToast?.close()
        debuffToast = nil
        let me = RewardCenter.me()
        let t = WitherDebuffToastWindow(above: me == .zero ? CGPoint(x: 600, y: 300) : me)
        debuffToast = t
        t.start()
        RewardCenter.say("🖤 위더 시듦! 20초!")
        SoundAndEffectsManager.shared.play(.heart)
    }

    // -- 블레이즈

    private func toggleBlaze() {
        if let b = blaze {
            b.disappear(defeated: false)
            blaze = nil
            RewardCenter.say("🔥 블레이즈 해제!")
            return
        }
        let pos = spawnBase()
        let b = BlazeWindow(startPos: pos, onShoot: { [weak self] from in
            self?.shootDarkFireball(from: from)
        }, onDefeat: { [weak self] in
            RewardCenter.grant(xp: 4, "🧪 양조 연료!")
            RewardCenter.say("🔥 블레이즈 격퇴!")
            SoundAndEffectsManager.shared.play(.chime)
            self?.blaze = nil
        })
        blaze = b
        b.start()
    }

    private func shootDarkFireball(from: CGPoint) {
        let target = RewardCenter.me()
        let t = target == .zero ? from : target
        let shot = DarkFireballWindow(from: from, target: t, onArrive: { [weak self] arrived in
            guard let self = self else { return }
            if arrived {
                RewardCenter.say("🔥 화염탄 직격!")
                SoundAndEffectsManager.shared.play(.explode)
                self.knockPlayer(dx: 24)
            } else {
                RewardCenter.say("🧱 튕-! 화염탄 격추!")
                SoundAndEffectsManager.shared.play(.pop)
            }
        })
        shot.launch()
        trackShot(shot)
    }

    // -- 익사자

    private func toggleDrowned() {
        if let d = drowned {
            d.disappear(defeated: false)
            drowned = nil
            RewardCenter.say("🧟‍♂️ 익사자 해제!")
            return
        }
        let pos = spawnBase()
        let d = DrownedWindow(startPos: pos, onThrow: { [weak self] from in
            self?.throwMiniTrident(from: from)
        }, onDefeat: { [weak self] in
            RewardCenter.grant(xp: 4, "🔱 삼지창 파편!")
            RewardCenter.say("🧟‍♂️ 익사자 격퇴!")
            SoundAndEffectsManager.shared.play(.splash)
            self?.drowned = nil
        })
        drowned = d
        d.start()
    }

    private func throwMiniTrident(from: CGPoint) {
        let target = RewardCenter.me()
        let t = target == .zero ? from : target
        let shot = MiniTridentWindow(from: from, target: t, onArrive: { [weak self] arrived in
            guard let self = self else { return }
            if arrived {
                RewardCenter.say("🌊 철퍽! 넉백!")
                SoundAndEffectsManager.shared.play(.splash)
                self.knockPlayer(dx: -20)
            } else {
                RewardCenter.say("🛡️ 챙-! 삼지창 쳐내기!")
                SoundAndEffectsManager.shared.play(.pop)
            }
        })
        shot.launch()
        trackShot(shot)
    }

    // -- 브리즈

    private func toggleBreeze() {
        if let b = breeze {
            b.disappear(defeated: false)
            breeze = nil
            RewardCenter.say("🌀 브리즈 해제!")
            return
        }
        let pos = spawnBase()
        let b = BreezeWindow(startPos: pos, onShoot: { [weak self] from in
            self?.shootWindCharge(from: from)
        }, onLeave: { [weak self] in
            self?.breeze = nil
        })
        breeze = b
        b.start()
    }

    private func shootWindCharge(from: CGPoint) {
        let target = RewardCenter.me()
        let t = target == .zero ? from : target
        let shot = WindChargeWindow(from: from, target: t, onArrive: { [weak self] arrived in
            guard let self = self else { return }
            if arrived {
                RewardCenter.say("💨 바람 직격! 넉백!")
                SoundAndEffectsManager.shared.play(.alert)
                self.knockPlayer(dx: 30)
            } else {
                // 테니스 반사 성공: 브리즈 즉사 +5XP
                RewardCenter.grant(xp: 5, "🌀 반사 성공!")
                RewardCenter.say("🌀 바람 반사! 즉사!")
                SoundAndEffectsManager.shared.play(.explode)
                self.breeze?.disappear(defeated: false)
                self.breeze = nil
            }
        })
        shot.launch()
        trackShot(shot)
    }

    // -- 실버피시

    private func toggleSilverfish() {
        if let s = silverfish {
            s.disappear(defeated: false)
            silverfish = nil
            RewardCenter.say("🪨 실버피시 해제!")
            return
        }
        let pos = spawnBase()
        let s = SilverfishWindow(startPos: pos, onDefeat: { [weak self] in
            RewardCenter.grant(xp: 1, "🪨 퇴치!")
            RewardCenter.say("🪨 실버피시 퇴치!")
            SoundAndEffectsManager.shared.play(.chime)
            self?.silverfish = nil
        })
        silverfish = s
        s.start()
    }

    // dropShot 미사용 시 shots 배열 정리용 (투사체는 자체 close로 정리)
    public func dismissAll() {
        wither?.disappear(defeated: false)
        blaze?.disappear(defeated: false)
        drowned?.disappear(defeated: false)
        breeze?.disappear(defeated: false)
        silverfish?.disappear(defeated: false)
        wither = nil
        blaze = nil
        drowned = nil
        breeze = nil
        silverfish = nil
        debuffToast?.close()
        debuffToast = nil
        for s in shots { s.close() }
        shots.removeAll()
    }
}
