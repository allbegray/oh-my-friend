import AppKit
import CoreGraphics
import Foundation

// 9차 야생동물 백로그: 토끼·북극곰·개구리·거북·발자국 + WildlifeManager.
// AppController "🎉 추가 모션" 서브메뉴에서 WildlifeManager.shared.entries()로 호출한다.

public final class WildlifeManager {
    public static let shared = WildlifeManager()

    private var rabbit: RabbitWindow?
    private var bear: PolarBearWindow?
    private var frog: FrogWindow?
    private var turtle: TurtleWindow?
    private var trail: FootprintTrail?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🐇 토끼 소환" }, { [weak self] in self?.toggleRabbit() }),
            ExtraMenuEntry({ "🐻 북극곰 소환" }, { [weak self] in self?.toggleBear() }),
            ExtraMenuEntry({ "🐸 개구리 소환" }, { [weak self] in self?.toggleFrog() }),
            ExtraMenuEntry({ "🐢 거북 소환" }, { [weak self] in self?.toggleTurtle() }),
            ExtraMenuEntry({ "🐾 발자국 추적" }, { [weak self] in self?.toggleTrail() }),
        ]
    }

    public func toggleRabbit() {
        if let w = rabbit, w.isVisible {
            w.close(); rabbit = nil; return
        }
        rabbit = nil
        let w = RabbitWindow(startPos: spawnPos(dx: -60)) { [weak self] tapped in
            self?.handleRabbitTap(tapped)
        }
        rabbit = w
        w.start()
    }

    public func toggleBear() {
        if let w = bear, w.isVisible {
            w.close(); bear = nil; return
        }
        bear = nil
        let w = PolarBearWindow(startPos: spawnPos(dx: 60)) { [weak self] tapped in
            self?.handleBearTap(tapped)
        }
        bear = w
        w.start()
    }

    public func toggleFrog() {
        if let w = frog, w.isVisible {
            w.close(); frog = nil; return
        }
        frog = nil
        let w = FrogWindow(startPos: spawnPos(dx: -100)) { [weak self] tapped in
            self?.handleFrogTap(tapped)
        }
        frog = w
        w.start()
    }

    public func toggleTurtle() {
        if let w = turtle, w.isVisible {
            w.close(); turtle = nil; return
        }
        turtle = nil
        let w = TurtleWindow(startPos: spawnPos(dx: 100)) { [weak self] tapped in
            self?.handleTurtleTap(tapped)
        }
        turtle = w
        w.start()
    }

    public func toggleTrail() {
        if let t = trail, t.isAlive {
            t.dismiss(); trail = nil; return
        }
        trail = nil
        let t = FootprintTrail(startPos: spawnPos(dx: 0)) { [weak self] in
            self?.handleTrailLoot()
        }
        trail = t
        t.show()
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

    private func handleRabbitTap(_ w: RabbitWindow) {
        if Double.random(in: 0..<1) < 0.10 {
            RewardCenter.grant(xp: 2, "🐇 행운의 토끼발!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("🐇 폴짝!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        w.hopBoost()
    }

    private func handleBearTap(_ w: PolarBearWindow) {
        if RewardCenter.heldItemName?() == "연어 🍣" {
            w.calm()
            RewardCenter.say("❤️")
            SoundAndEffectsManager.shared.play(.heart)
        } else {
            w.enrage()
            RewardCenter.say("🐻 새끼를 건드리지 마!")
            SoundAndEffectsManager.shared.play(.alert)
        }
    }

    private func handleFrogTap(_ w: FrogWindow) {
        w.flickTongue()
        RewardCenter.say("🐸 개굴!")
        SoundAndEffectsManager.shared.play(.pop)
    }

    private func handleTurtleTap(_ w: TurtleWindow) {
        if w.collectShell() {
            RewardCenter.grant(xp: 2, "🌊 물의 호흡!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("🐢 ...")
            SoundAndEffectsManager.shared.play(.pop)
        }
    }

    private func handleTrailLoot() {
        if Bool.random() {
            RewardCenter.grant(xp: 3, "🦴 뼈다귀!")
        } else {
            RewardCenter.grant(xp: 3, "💚 에메랄드!")
        }
        SoundAndEffectsManager.shared.play(.chime)
        trail?.dismiss()
        trail = nil
    }
}

// MARK: - 토끼: 깡충 점프 이동 + 빨간 눈, 당근 유혹 1.4배속 추적

public final class RabbitWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (RabbitWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var boost: TimeInterval = 0
    private var drawView: RabbitDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 48
    private let baseSpeed: CGFloat = 42

    public init(startPos: CGPoint, onTap: @escaping (RabbitWindow) -> Void) {
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
        let view = RabbitDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.boost > 0 { self.boost -= 1.0 / 60.0 }
            let lured = RewardCenter.heldItemName?() == "당근 🥕"
            var speed = self.baseSpeed
            if lured {
                speed *= 1.4
                let me = RewardCenter.me()
                if me != .zero {
                    let d = me.x - self.position.x
                    if abs(d) > 8 { self.dir = d > 0 ? 1 : -1 }
                }
            } else if Int(self.phase) % 3 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * speed / 60.0
            let hop = abs(sin(self.phase * 7.0)) * 16.0 + (self.boost > 0 ? 8.0 : 0)
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hop))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.hop = hop
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func hopBoost() {
        boost = 0.6
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

private final class RabbitDrawView: NSView {
    var facingRight = true
    var hop: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        let squash: CGFloat = hop > 2 ? 1.0 : 0.85
        // 몸통 (회갈색)
        ctx.setFillColor(red: 0.72, green: 0.60, blue: 0.50, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 8, width: 34, height: 24 * squash + 6))
        // 머리
        ctx.fillEllipse(in: CGRect(x: 40, y: 22, width: 18, height: 16))
        // 긴 귀 2개
        ctx.fill(CGRect(x: 44, y: 36, width: 5, height: 12))
        ctx.fill(CGRect(x: 51, y: 36, width: 5, height: 12))
        ctx.setFillColor(red: 0.95, green: 0.75, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 45, y: 38, width: 3, height: 8))
        // 빨간 눈
        ctx.setFillColor(red: 0.90, green: 0.10, blue: 0.12, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 50, y: 29, width: 4, height: 5))
        // 뒷다리 (깡충)
        ctx.setFillColor(red: 0.65, green: 0.53, blue: 0.44, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 14, y: 2, width: 16, height: 10))
        // 꼬리 (흰 뭉게)
        ctx.setFillColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 6, y: 14, width: 9, height: 9))
        ctx.restoreGState()
    }
}

// MARK: - 북극곰: 느릿 중립 배회, 클릭 시 5초 분노 추격 / 연어 진정

public final class PolarBearWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (PolarBearWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var rageLeft: TimeInterval = 0
    private var drawView: PolarBearDrawView?
    private let panelW: CGFloat = 84
    private let panelH: CGFloat = 56
    private let baseSpeed: CGFloat = 18

    public init(startPos: CGPoint, onTap: @escaping (PolarBearWindow) -> Void) {
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
        let view = PolarBearDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.rageLeft > 0 {
                self.rageLeft -= 1.0 / 60.0
                let me = RewardCenter.me()
                if me != .zero {
                    let d = me.x - self.position.x
                    if abs(d) > 6 { self.dir = d > 0 ? 1 : -1 }
                }
                self.position.x += self.dir * self.baseSpeed * 2.0 / 60.0
            } else {
                if Int(self.phase) % 5 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                    self.dir = Bool.random() ? 1 : -1
                }
                self.position.x += self.dir * self.baseSpeed / 60.0
            }
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.enraged = self.rageLeft > 0
            self.drawView?.bob = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func enrage() {
        rageLeft = 5.0
    }

    public func calm() {
        rageLeft = 0
    }

    public var isEnraged: Bool { rageLeft > 0 }

    public override func mouseDown(with event: NSEvent) {
        onTap(self)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class PolarBearDrawView: NSView {
    var facingRight = true
    var enraged = false
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통 (흰색, 분노 시 붉은 기운)
        if enraged {
            ctx.setFillColor(red: 1.0, green: 0.88, blue: 0.88, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1.0)
        }
        ctx.fillEllipse(in: CGRect(x: 10, y: 10 + bob, width: 52, height: 30))
        // 머리
        ctx.fillEllipse(in: CGRect(x: 56, y: 22 + bob, width: 20, height: 18))
        // 주둥이
        ctx.setFillColor(red: 0.90, green: 0.90, blue: 0.92, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 66, y: 24 + bob, width: 10, height: 8))
        ctx.setFillColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 71, y: 27 + bob, width: 3, height: 3))
        // 눈 (분노 시 빨강)
        if enraged {
            ctx.setFillColor(red: 0.95, green: 0.10, blue: 0.10, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
        }
        ctx.fillEllipse(in: CGRect(x: 63, y: 31 + bob, width: 4, height: 4))
        // 귀
        ctx.setFillColor(red: 0.93, green: 0.93, blue: 0.94, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 57, y: 36 + bob, width: 7, height: 7))
        // 다리 4개
        ctx.setFillColor(red: 0.90, green: 0.90, blue: 0.91, alpha: 1.0)
        for x in [16, 28, 44, 54] as [CGFloat] {
            ctx.fill(CGRect(x: x, y: 2, width: 8, height: 12))
        }
        // 분노 마크
        if enraged {
            ctx.setFillColor(red: 1.0, green: 0.25, blue: 0.20, alpha: 1.0)
            ctx.fill(CGRect(x: 38, y: 46, width: 4, height: 8))
            ctx.fill(CGRect(x: 42, y: 46, width: 4, height: 8))
        }
        ctx.restoreGState()
    }
}

// MARK: - 개구리: 점프 이동 + 0.6초 혀 발사 + 파리 사냥 +1XP

public final class FrogWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (FrogWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var tongueLeft: TimeInterval = 0
    private var flyAngle: Double = 0
    private var drawView: FrogDrawView?
    private let panelW: CGFloat = 52
    private let panelH: CGFloat = 40
    private let tonguePeriod: TimeInterval = 0.6

    public init(startPos: CGPoint, onTap: @escaping (FrogWindow) -> Void) {
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
        let view = FrogDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.flyAngle += (1.0 / 60.0) * 2.4
            if Int(self.phase) % 3 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            // 깡충 점프 이동
            let hopCycle = sin(self.phase * 5.0)
            if hopCycle > 0.3 {
                self.position.x += self.dir * 55.0 / 60.0
            }
            let hop = max(0, hopCycle) * 14.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y + hop))
            // 0.6초 주기 혀 발사
            if self.tongueLeft > 0 {
                self.tongueLeft -= 1.0 / 60.0
            } else if fmod(self.phase, self.tonguePeriod) < (1.0 / 60.0) {
                self.tongueLeft = 0.18
            }
            // 파리 사냥 판정: 혀가 나가 있는 순간 파리가 혀 범위 안에 있으면 포획
            if self.tongueLeft > 0 {
                let fly = self.flyOffset()
                if abs(fly.x) < 30 && abs(fly.y - 14) < 12 {
                    self.flyAngle = Double.random(in: 0..<(Double.pi * 2))
                    RewardCenter.grant(xp: 1, "🐸 파리 냠!")
                    SoundAndEffectsManager.shared.play(.gulp)
                }
            }
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.hop = hop
            self.drawView?.tongueOut = self.tongueLeft > 0
            self.drawView?.fly = self.flyOffset()
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func flickTongue() {
        tongueLeft = 0.25
    }

    private func flyOffset() -> CGPoint {
        return CGPoint(x: cos(flyAngle) * 22, y: 22 + sin(flyAngle) * 10)
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

private final class FrogDrawView: NSView {
    var facingRight = true
    var hop: CGFloat = 0
    var tongueOut = false
    var fly = CGPoint.zero

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: w, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        // 몸통 (초록)
        ctx.setFillColor(red: 0.30, green: 0.70, blue: 0.30, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 6, width: 30, height: 20))
        // 머리 + 불룩 눈 2개
        ctx.fillEllipse(in: CGRect(x: 30, y: 16, width: 16, height: 14))
        ctx.setFillColor(red: 0.35, green: 0.75, blue: 0.32, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 31, y: 28, width: 8, height: 8))
        ctx.fillEllipse(in: CGRect(x: 39, y: 28, width: 8, height: 8))
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 33, y: 31, width: 4, height: 4))
        ctx.fillEllipse(in: CGRect(x: 41, y: 31, width: 4, height: 4))
        // 뒷다리
        ctx.setFillColor(red: 0.25, green: 0.62, blue: 0.25, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 4, y: 2, width: 16, height: 10))
        // 혀 (0.6초 주기 발사 선)
        if tongueOut {
            ctx.setStrokeColor(red: 1.0, green: 0.45, blue: 0.55, alpha: 1.0)
            ctx.setLineWidth(2.5)
            ctx.move(to: CGPoint(x: 44, y: 20))
            ctx.addLine(to: CGPoint(x: 62, y: 20))
            ctx.strokePath()
            ctx.setFillColor(red: 1.0, green: 0.45, blue: 0.55, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 60, y: 17, width: 6, height: 6))
        }
        // 파리
        let fx = bounds.width / 2 + fly.x
        let fy = fly.y
        ctx.setFillColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: fx - 2, y: fy - 2, width: 4, height: 4))
        ctx.setFillColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 0.8)
        ctx.fillEllipse(in: CGRect(x: fx - 3, y: fy + 1, width: 3, height: 2))
        ctx.fillEllipse(in: CGRect(x: fx, y: fy + 1, width: 3, height: 2))
        ctx.restoreGState()
    }
}

// MARK: - 거북: 느릿 보행, 클릭 시 인갑 조각 +2XP

public final class TurtleWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (TurtleWindow) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var dir: CGFloat = 1
    private var cooldown: TimeInterval = 0
    private var drawView: TurtleDrawView?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 44

    public init(startPos: CGPoint, onTap: @escaping (TurtleWindow) -> Void) {
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
        let view = TurtleDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.splash)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.cooldown > 0 { self.cooldown -= 1.0 / 60.0 }
            if Int(self.phase) % 6 == 0 && Int(self.phase * 60.0) % 60 == 0 {
                self.dir = Bool.random() ? 1 : -1
            }
            self.position.x += self.dir * 12.0 / 60.0
            self.setFrameOrigin(NSPoint(x: self.position.x - self.panelW / 2, y: self.position.y))
            self.drawView?.facingRight = self.dir > 0
            self.drawView?.step = sin(self.phase * 3.0)
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public func collectShell() -> Bool {
        guard cooldown <= 0 else { return false }
        cooldown = 3.0
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

private final class TurtleDrawView: NSView {
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
        // 등딱지 (초록 육각 느낌)
        ctx.setFillColor(red: 0.25, green: 0.55, blue: 0.28, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 12, y: 12, width: 44, height: 26))
        // 등딱지 무늬
        ctx.setFillColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 22, y: 20, width: 12, height: 10))
        ctx.fillEllipse(in: CGRect(x: 36, y: 20, width: 12, height: 10))
        ctx.setStrokeColor(red: 0.18, green: 0.42, blue: 0.20, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: 12, y: 12, width: 44, height: 26))
        // 머리
        ctx.setFillColor(red: 0.45, green: 0.72, blue: 0.42, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 54, y: 16, width: 14, height: 12))
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 61, y: 21, width: 3, height: 3))
        // 다리 4개 (느릿 발걸음)
        ctx.setFillColor(red: 0.40, green: 0.66, blue: 0.38, alpha: 1.0)
        let lift = step * 1.5
        ctx.fill(CGRect(x: 18, y: 2 + (lift > 0 ? lift : 0), width: 8, height: 10))
        ctx.fill(CGRect(x: 32, y: 2 + (lift < 0 ? -lift : 0), width: 8, height: 10))
        ctx.fill(CGRect(x: 46, y: 2 + (lift > 0 ? lift : 0), width: 8, height: 10))
        ctx.restoreGState()
    }
}

// MARK: - 발자국: 바닥 8개 트레일, 마지막 클릭 시 랜덤 전리품 +3XP

public final class FootprintTrail {
    private var prints: [FootprintWindow] = []
    private let onLastTap: () -> Void

    public init(startPos: CGPoint, onLastTap: @escaping () -> Void) {
        self.onLastTap = onLastTap
        for i in 0..<8 {
            let pos = CGPoint(x: startPos.x + CGFloat(i) * 26 - 91, y: startPos.y - 6)
            let isLast = (i == 7)
            let w = FootprintWindow(floorPos: pos, isLast: isLast, index: i) { [weak self] in
                guard let self = self else { return }
                if isLast { self.onLastTap() }
                else {
                    RewardCenter.say("🐾 ...")
                    SoundAndEffectsManager.shared.play(.pop)
                }
            }
            prints.append(w)
        }
    }

    public var isAlive: Bool {
        return prints.contains { $0.isVisible }
    }

    public func show() {
        for (i, w) in prints.enumerated() {
            // 순차 등장 연출
            let delay = Double(i) * 0.12
            let win = w
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                win.orderFrontRegardless()
            }
        }
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func dismiss() {
        for w in prints {
            w.close()
        }
        prints.removeAll()
    }
}

public final class FootprintWindow: NSPanel {
    public var position: CGPoint
    public let isLast: Bool
    public let index: Int
    private let onTap: () -> Void

    public init(floorPos: CGPoint, isLast: Bool, index: Int, onTap: @escaping () -> Void) {
        self.position = floorPos
        self.isLast = isLast
        self.index = index
        self.onTap = onTap
        let size = NSSize(width: 28, height: 28)
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
        let view = FootprintDrawView(frame: NSRect(origin: .zero, size: size), isLast: isLast, flip: index % 2 == 1)
        contentView = view
    }

    public override func mouseDown(with event: NSEvent) {
        onTap()
    }

    public override func close() {
        super.close()
    }
}

private final class FootprintDrawView: NSView {
    private let isLast: Bool
    private let flip: Bool

    init(frame: NSRect, isLast: Bool, flip: Bool) {
        self.isLast = isLast
        self.flip = flip
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if flip {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1.0, y: 1.0)
        }
        if isLast {
            // 마지막 발자국: 황금빛 반짝임
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 0.75)
        }
        // 발바닥 타원 + 발가락 3개
        ctx.fillEllipse(in: CGRect(x: 8, y: 4, width: 12, height: 14))
        ctx.fillEllipse(in: CGRect(x: 7, y: 17, width: 5, height: 5))
        ctx.fillEllipse(in: CGRect(x: 12, y: 19, width: 5, height: 5))
        ctx.fillEllipse(in: CGRect(x: 17, y: 17, width: 5, height: 5))
        if isLast {
            ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
            ctx.fillEllipse(in: CGRect(x: 11, y: 8, width: 3, height: 4))
        }
        ctx.restoreGState()
    }
}
