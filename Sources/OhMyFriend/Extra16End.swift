import AppKit
import CoreGraphics
import Foundation

// 16차 백로그(엔드 5종): 후렴과·셜커·드래곤알·화염저항·공허안개 + EndManager.
// ExtraBacklog.swift의 ExtraMenuEntry/RewardCenter API만 사용. UserDefaults 키 1개.

// MARK: - 후렴과 패널

private final class Extra16ChorusDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.35, green: 0.15, blue: 0.55, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 16, y: 8, width: 32, height: 40))
        ctx.setFillColor(red: 0.55, green: 0.3, blue: 0.8, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 10, y: 16, width: 8, height: 8))
        ctx.fill(CGRect(x: w / 2.0 + 2, y: 28, width: 8, height: 8))
        ctx.setFillColor(red: 0.2, green: 0.35, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 3, y: 48, width: 6, height: 10))
    }
}

private final class Extra16ChorusWindow: NSPanel {
    var onEat: (() -> Void)?
    init(floorPos: CGPoint, onEat: @escaping () -> Void) {
        self.onEat = onEat
        let size = NSSize(width: 72, height: 72)
        let frame = NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = Extra16ChorusDrawView(frame: NSRect(origin: .zero, size: size))
    }
    func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
    override func mouseDown(with event: NSEvent) {
        onEat?()
    }
}

// MARK: - 셜커 상자 패널

private final class Extra16ShulkerDrawView: NSView {
    var storedXP: Int = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.5, green: 0.2, blue: 0.65, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 0, width: w - 16, height: 34))
        ctx.setFillColor(red: 0.62, green: 0.32, blue: 0.78, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 34, width: w - 16, height: 16))
        ctx.setFillColor(red: 0.85, green: 0.75, blue: 0.95, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 5, y: 22, width: 10, height: 10))
        if storedXP > 0 {
            let text = NSAttributedString(string: "+\(storedXP)XP", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
            text.draw(at: NSPoint(x: w / 2.0 - 20, y: 52))
        }
    }
}

private final class Extra16ShulkerWindow: NSPanel {
    var onToggle: (() -> Void)?
    let drawView: Extra16ShulkerDrawView
    init(floorPos: CGPoint, storedXP: Int, onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        let size = NSSize(width: 84, height: 68)
        let frame = NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height)
        self.drawView = Extra16ShulkerDrawView(frame: NSRect(origin: .zero, size: size))
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        drawView.storedXP = storedXP
        contentView = drawView
    }
    func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
    func refresh(storedXP: Int) {
        drawView.storedXP = storedXP
        drawView.needsDisplay = true
    }
    override func mouseDown(with event: NSEvent) {
        onToggle?()
    }
}

// MARK: - 드래곤 알 패널

private final class Extra16EggDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.45, green: 0.4, blue: 0.35, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2.0 - 24, y: 0, width: 48, height: 8))
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 16, y: 8, width: 32, height: 42))
        ctx.setFillColor(red: 0.25, green: 0.22, blue: 0.28, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 8, y: 26, width: 10, height: 12))
    }
}

private final class Extra16EggWindow: NSPanel {
    var onPoke: (() -> Void)?
    init(floorPos: CGPoint, onPoke: @escaping () -> Void) {
        self.onPoke = onPoke
        let size = NSSize(width: 72, height: 62)
        let frame = NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = Extra16EggDrawView(frame: NSRect(origin: .zero, size: size))
    }
    func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
    func teleportNearby() {
        var f = frame
        f.origin.x += CGFloat.random(in: -140...140)
        f.origin.y += CGFloat.random(in: -80...120)
        setFrame(f, display: true)
    }
    override func mouseDown(with event: NSEvent) {
        onPoke?()
    }
}

// MARK: - 마그마 크림 연출 패널 (자동 정리)

private final class Extra16MagmaDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 0.95)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 18, y: h / 2.0 - 18, width: 36, height: 36))
        ctx.setFillColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.95)
        ctx.fillEllipse(in: CGRect(x: w / 2.0 - 9, y: h / 2.0 - 9, width: 18, height: 18))
    }
}

private final class Extra16MagmaWindow: NSPanel {
    private var closeTimer: Timer?
    init(floorPos: CGPoint) {
        let size = NSSize(width: 64, height: 64)
        let frame = NSRect(x: floorPos.x - size.width / 2.0, y: floorPos.y, width: size.width, height: size.height)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = Extra16MagmaDrawView(frame: NSRect(origin: .zero, size: size))
    }
    func spawn() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.gulp)
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] t in
            t.invalidate()
            self?.close()
        }
        if let t = closeTimer { RunLoop.main.add(t, forMode: .common) }
    }
    override func close() {
        closeTimer?.invalidate()
        closeTimer = nil
        super.close()
    }
}

// MARK: - 공허 안개 오버레이 (클릭 무시)

private final class Extra16FogDrawView: NSView {
    var phase: CGFloat = 0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let edge: CGFloat = 90
        let pulse = 0.45 + 0.12 * sin(phase)
        ctx.setFillColor(red: 0.35, green: 0.05, blue: 0.6, alpha: pulse)
        ctx.fill(CGRect(x: 0, y: h - edge, width: w, height: edge))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: edge))
        ctx.fill(CGRect(x: 0, y: 0, width: edge, height: h))
        ctx.fill(CGRect(x: w - edge, y: 0, width: edge, height: h))
    }
}

private final class Extra16FogWindow: NSPanel {
    private var animTimer: Timer?
    private var phase: CGFloat = 0
    private let drawView: Extra16FogDrawView
    init() {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        self.drawView = Extra16FogDrawView(frame: NSRect(origin: .zero, size: frame.size))
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = drawView
    }
    func spawn() {
        orderFrontRegardless()
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 0.15
            self.drawView.phase = self.phase
            self.drawView.needsDisplay = true
        }
        if let t = animTimer { RunLoop.main.add(t, forMode: .common) }
    }
    override func close() {
        animTimer?.invalidate()
        animTimer = nil
        super.close()
    }
}

// MARK: - EndManager

public final class EndManager {
    public static let shared = EndManager()
    private init() {}

    private static let shulkerKey = "Extra16End.shulkerXP"

    private var chorusWindow: Extra16ChorusWindow?
    private var shulkerWindow: Extra16ShulkerWindow?
    private var eggWindow: Extra16EggWindow?
    private var magmaWindow: Extra16MagmaWindow?
    private var fogWindow: Extra16FogWindow?

    private var chorusCooldownUntil = Date.distantPast
    private var fireResistUntil = Date.distantPast
    private var fireResistTimer: Timer?

    private func basePos() -> CGPoint {
        let p = RewardCenter.me()
        if p != .zero { return p }
        if let s = NSScreen.main {
            return CGPoint(x: s.frame.midX, y: s.frame.minY + 200)
        }
        return CGPoint(x: 600, y: 200)
    }

    private func isNight() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 22 || h < 4
    }

    private func isFireResistActive() -> Bool {
        return Date() < fireResistUntil
    }

    private func fireResistRemaining() -> Int {
        return max(0, Int(fireResistUntil.timeIntervalSinceNow.rounded(.up)))
    }

    // MARK: 메뉴

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ [weak self] in self?.chorusTitle() ?? "🍇 후렴과 먹기" }, { [weak self] in self?.runChorus() }),
            ExtraMenuEntry({ [weak self] in self?.shulkerTitle() ?? "💜 셜커 상자" }, { [weak self] in self?.runShulker() }),
            ExtraMenuEntry({ "🥚 드래곤 알" }, { [weak self] in self?.runEgg() }),
            ExtraMenuEntry({ [weak self] in self?.fireTitle() ?? "🧪 화염 저항" }, { [weak self] in self?.runFireResist() }),
            ExtraMenuEntry({ [weak self] in self?.fogTitle() ?? "🌌 공허 안개" }, { [weak self] in self?.runFog() }),
        ]
    }

    private func chorusTitle() -> String {
        let remain = Int(chorusCooldownUntil.timeIntervalSinceNow.rounded(.up))
        if remain > 0 { return "🍇 후렴과 먹기 (\(remain)s)" }
        return "🍇 후렴과 먹기"
    }

    private func shulkerTitle() -> String {
        let stored = UserDefaults.standard.integer(forKey: Self.shulkerKey)
        if stored > 0 { return "💜 셜커 상자 (+\(stored)XP 보관중)" }
        return "💜 셜커 상자"
    }

    private func fireTitle() -> String {
        if isFireResistActive() { return "🧪 화염 저항 (\(fireResistRemaining())s)" }
        return "🧪 화염 저항"
    }

    private func fogTitle() -> String {
        if fogWindow != nil { return "🌌 공허 안개 ON" }
        return "🌌 공허 안개"
    }

    // MARK: 1. 후렴과

    private func runChorus() {
        if chorusWindow == nil {
            let w = Extra16ChorusWindow(floorPos: basePos()) { [weak self] in self?.eatChorus() }
            chorusWindow = w
            w.spawn()
        } else {
            chorusWindow?.orderFrontRegardless()
        }
        eatChorus()
    }

    private func eatChorus() {
        let now = Date()
        if now < chorusCooldownUntil {
            let remain = Int(chorusCooldownUntil.timeIntervalSinceNow.rounded(.up))
            RewardCenter.say("🍇 \(remain)초 뒤에...")
            return
        }
        chorusCooldownUntil = now.addingTimeInterval(10)
        SoundAndEffectsManager.shared.play(.gulp)
        let me = RewardCenter.me()
        let dx = CGFloat.random(in: -300...300)
        let dy = CGFloat.random(in: -300...300)
        if let mover = RewardCenter.movePlayer {
            mover(CGPoint(x: me.x + dx, y: me.y + dy))
            RewardCenter.say("🌀 뿅!")
        } else {
            RewardCenter.say("🌀 뿅! (이동 불가)")
        }
        RewardCenter.grant(xp: 1, "🍇")
    }

    // MARK: 2. 셜커 상자

    private func runShulker() {
        let stored = UserDefaults.standard.integer(forKey: Self.shulkerKey)
        if shulkerWindow == nil {
            let w = Extra16ShulkerWindow(floorPos: basePos(), storedXP: stored) { [weak self] in self?.toggleShulker() }
            shulkerWindow = w
            w.spawn()
        } else {
            shulkerWindow?.refresh(storedXP: stored)
            shulkerWindow?.orderFrontRegardless()
        }
        toggleShulker()
    }

    private func toggleShulker() {
        let stored = UserDefaults.standard.integer(forKey: Self.shulkerKey)
        if stored > 0 {
            UserDefaults.standard.set(0, forKey: Self.shulkerKey)
            SoundAndEffectsManager.shared.play(.chime)
            RewardCenter.grant(xp: stored, "💜")
            RewardCenter.say("💜 꺼내기!")
        } else {
            UserDefaults.standard.set(5, forKey: Self.shulkerKey)
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("💜 보관! (+5XP)")
        }
        let now = UserDefaults.standard.integer(forKey: Self.shulkerKey)
        shulkerWindow?.refresh(storedXP: now)
    }

    // MARK: 3. 드래곤 알

    private func runEgg() {
        if eggWindow == nil {
            let w = Extra16EggWindow(floorPos: basePos()) { [weak self] in self?.pokeEgg() }
            eggWindow = w
            w.spawn()
        } else {
            eggWindow?.orderFrontRegardless()
        }
        RewardCenter.say("🥚 드래곤 알?!")
    }

    private func pokeEgg() {
        eggWindow?.teleportNearby()
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🐲 슈우웅!")
        RewardCenter.grant(xp: 2, "🥚")
    }

    // MARK: 4. 화염 저항

    private func runFireResist() {
        if isFireResistActive() {
            RewardCenter.say("🔥 끄떡없다!")
            RewardCenter.grant(xp: 2, "🧪")
            return
        }
        let held = RewardCenter.heldItemName?() ?? ""
        if !held.contains("빈 양동이") {
            RewardCenter.say("🪣 빈 양동이를 들어줘!")
            return
        }
        magmaWindow?.close()
        let w = Extra16MagmaWindow(floorPos: basePos())
        magmaWindow = w
        w.spawn()
        fireResistUntil = Date().addingTimeInterval(90)
        fireResistTimer?.invalidate()
        fireResistTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: false) { [weak self] t in
            t.invalidate()
            self?.fireResistTimer = nil
        }
        if let t = fireResistTimer { RunLoop.main.add(t, forMode: .common) }
        RewardCenter.say("🔥 끄떡없다!")
        RewardCenter.grant(xp: 2, "🧪")
    }

    // MARK: 5. 공허 안개

    private func runFog() {
        if let f = fogWindow {
            f.close()
            fogWindow = nil
            return
        }
        if !isNight() {
            RewardCenter.say("🌌 심야에만...")
        }
        let w = Extra16FogWindow()
        fogWindow = w
        w.spawn()
        SoundAndEffectsManager.shared.play(.pop)
    }
}
