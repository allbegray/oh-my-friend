import AppKit
import CoreGraphics
import Foundation

// 14차 겨울 백로그: 눈보라·얼음·별똥별·대나무발판·캠프요리 + WinterManager.
// RewardCenter 브리지(playerPos/movePlayer/friendPos/onReward)만 사용, UserDefaults/네트워크 미사용.

public final class WinterManager {
    public static let shared = WinterManager()

    private var retained: [NSPanel] = []

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "❄️ 눈보라" }, { [weak self] in self?.runBlizzard() }),
            ExtraMenuEntry({ "🧊 얼음 미끄럼틀" }, { [weak self] in self?.runIceSlide() }),
            ExtraMenuEntry({ "⭐ 별똥별 소원" }, { [weak self] in self?.runShootingStar() }),
            ExtraMenuEntry({ "🎍 대나무 발판" }, { [weak self] in self?.runBamboo() }),
            ExtraMenuEntry({ "🍳 캠프 요리" }, { [weak self] in self?.runCampCook() })
        ]
    }

    // MARK: - 공용

    private func keep(_ panel: NSPanel) {
        retained.append(panel)
    }

    private func release(_ panel: NSPanel) {
        retained.removeAll { $0 === panel }
    }

    private func toast(_ message: String, at pos: CGPoint, duration: TimeInterval = 2.0) {
        let panel = WinterToastPanel(message: message, at: pos)
        keep(panel)
        panel.show(duration: duration) { [weak self, weak panel] in
            guard let p = panel else { return }
            self?.release(p)
        }
    }

    // MARK: - 1. 눈보라 + 눈싸움

    private func runBlizzard() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 900, height: 600)
        let overlay = SnowstormOverlayPanel(screenFrame: screenFrame)
        keep(overlay)
        overlay.show(duration: 60.0) { [weak self, weak overlay] in
            guard let o = overlay else { return }
            self?.release(o)
        }
        SoundAndEffectsManager.shared.play(.splash)
        RewardCenter.say("❄️ 눈보라 시작!")

        let me = RewardCenter.me()
        for i in 0..<3 {
            let pos = CGPoint(x: me.x + CGFloat(i - 1) * 90.0, y: me.y - 10)
            let ball = SnowballPanel(at: pos) { [weak self] in
                self?.throwSnowball(from: pos)
            }
            keep(ball)
            ball.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) { [weak self, weak ball] in
                guard let self = self, let b = ball, self.retained.contains(where: { $0 === b }) else { return }
                b.close()
                self.release(b)
            }
        }
    }

    private func throwSnowball(from pos: CGPoint) {
        let target = RewardCenter.friendPos?() ?? CGPoint(x: pos.x + 220, y: pos.y + 40)
        let flight = SnowballFlightPanel(from: pos, to: target)
        keep(flight)
        SoundAndEffectsManager.shared.play(.pop)
        flight.show(duration: 0.6) { [weak self, weak flight] in
            guard let f = flight else { return }
            self?.release(f)
            self?.toast("⛄ 명중!", at: target, duration: 1.5)
            RewardCenter.grant(xp: 2, "⛄ 명중!")
            SoundAndEffectsManager.shared.play(.heart)
        }
    }

    // MARK: - 2. 얼음 미끄럼틀

    private func runIceSlide() {
        let me = RewardCenter.me()
        let panel = IceSlidePanel(at: me) { [weak self] in
            guard let self = self else { return }
            guard let move = RewardCenter.movePlayer else {
                RewardCenter.say("🧊 미끄럼틀 준비! (이동 불가)")
                SoundAndEffectsManager.shared.play(.alert)
                return
            }
            let cur = RewardCenter.me()
            move(CGPoint(x: cur.x + 150, y: cur.y))
            RewardCenter.say("🧊 쌩쌩!")
            SoundAndEffectsManager.shared.play(.splash)
        }
        keep(panel)
        panel.show()
        SoundAndEffectsManager.shared.play(.pop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self, weak panel] in
            guard let self = self, let p = panel, self.retained.contains(where: { $0 === p }) else { return }
            p.close()
            self.release(p)
        }
    }

    // MARK: - 3. 별똥별 소원 (밤 18시~06시만)

    private func runShootingStar() {
        let hour = Calendar.current.component(.hour, from: Date())
        let isNight = (hour >= 18 || hour < 6)
        if !isNight {
            RewardCenter.say("🌠 밤(18시~06시)에 빌 수 있어!")
            SoundAndEffectsManager.shared.play(.alert)
            return
        }
        let me = RewardCenter.me()
        let start = CGPoint(x: me.x + 260, y: me.y + 260)
        let panel = ShootingStarPanel(at: start) { [weak self] in
            RewardCenter.grant(xp: 5, "🌠 소원 빌기!")
            SoundAndEffectsManager.shared.play(.chime)
            if let self = self {
                self.toast("🌠 소원이 이루어질 거야!", at: start, duration: 2.0)
            }
        }
        keep(panel)
        panel.show()
        SoundAndEffectsManager.shared.play(.pop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) { [weak self, weak panel] in
            guard let self = self, let p = panel, self.retained.contains(where: { $0 === p }) else { return }
            p.close()
            self.release(p)
        }
    }

    // MARK: - 4. 대나무 발판 (3단 성장)

    private func runBamboo() {
        let me = RewardCenter.me()
        let panel = BambooPanel(at: me) { [weak self] in
            guard let move = RewardCenter.movePlayer else {
                RewardCenter.say("🎍 대나무 발판! (이동 불가)")
                SoundAndEffectsManager.shared.play(.alert)
                return
            }
            let cur = RewardCenter.me()
            move(CGPoint(x: cur.x, y: cur.y + 180))
            RewardCenter.say("🐼 대나무다!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        keep(panel)
        panel.show()
        SoundAndEffectsManager.shared.play(.splash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self, weak panel] in
            guard let self = self, let p = panel, self.retained.contains(where: { $0 === p }) else { return }
            p.close()
            self.release(p)
        }
    }

    // MARK: - 5. 캠프 요리 (5초 조리)

    private func runCampCook() {
        let me = RewardCenter.me()
        let panel = CampCookPanel(at: me, onHint: {
            RewardCenter.say("지글지글...")
        }, onDone: { [weak self] pos in
            RewardCenter.grant(xp: 4, "👨‍🍳 완성! 맛있게 먹었다!")
            SoundAndEffectsManager.shared.play(.heart)
            self?.toast("👨‍🍳 완성!", at: pos, duration: 2.0)
        })
        keep(panel)
        panel.show()
        SoundAndEffectsManager.shared.play(.splash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 40.0) { [weak self, weak panel] in
            guard let self = self, let p = panel, self.retained.contains(where: { $0 === p }) else { return }
            p.close()
            self.release(p)
        }
    }
}

// MARK: - 토스트

private final class WinterToastPanel: NSPanel {
    private var onClose: (() -> Void)?

    init(message: String, at pos: CGPoint) {
        let size = NSSize(width: 240, height: 56)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y, width: size.width, height: size.height),
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
        contentView = WinterToastDrawView(frame: NSRect(origin: .zero, size: size), message: message)
    }

    func show(duration: TimeInterval, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.close()
        }
    }

    override func close() {
        super.close()
        onClose?()
        onClose = nil
    }
}

private final class WinterToastDrawView: NSView {
    private let message: String

    init(frame: NSRect, message: String) {
        self.message = message
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        self.message = ""
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.88)
        ctx.beginPath()
        ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.fillPath()
        let text = message as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        let tsize = text.size(withAttributes: attrs)
        text.draw(
            at: NSPoint(x: (bounds.width - tsize.width) / 2.0, y: (bounds.height - tsize.height) / 2.0),
            withAttributes: attrs
        )
    }
}

// MARK: - 눈보라 오버레이 (클릭 무시, 60초 자동 정리)

private final class SnowstormOverlayPanel: NSPanel {
    private var timer: Timer?
    private var flakes: [CGPoint] = []
    private var drawView: SnowstormDrawView?
    private var onClose: (() -> Void)?

    init(screenFrame: NSRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) - 2)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = SnowstormDrawView(frame: NSRect(origin: .zero, size: screenFrame.size))
        self.drawView = view
        contentView = view
        for _ in 0..<120 {
            flakes.append(CGPoint(
                x: CGFloat.random(in: 0...screenFrame.width),
                y: CGFloat.random(in: 0...screenFrame.height)
            ))
        }
    }

    func show(duration: TimeInterval, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        orderFrontRegardless()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] t in
            guard let self = self, let view = self.drawView else { t.invalidate(); return }
            let h = view.bounds.height
            let w = view.bounds.width
            for i in self.flakes.indices {
                self.flakes[i].y -= CGFloat.random(in: 4...9)
                self.flakes[i].x -= CGFloat.random(in: 1...4)
                if self.flakes[i].y < 0 {
                    self.flakes[i] = CGPoint(x: CGFloat.random(in: 0...w), y: h)
                }
            }
            view.flakes = self.flakes
            view.needsDisplay = true
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.close()
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClose?()
        onClose = nil
    }
}

private final class SnowstormDrawView: NSView {
    var flakes: [CGPoint] = []

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        for f in flakes {
            ctx.fillEllipse(in: CGRect(x: f.x, y: f.y, width: 5, height: 5))
        }
        let label = "❄️" as NSString
        label.draw(at: NSPoint(x: 12, y: bounds.height - 40), withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
    }
}

// MARK: - 눈덩이 (클릭 시 투척)

private final class SnowballPanel: NSPanel {
    private let onThrow: () -> Void

    init(at pos: CGPoint, onThrow: @escaping () -> Void) {
        self.onThrow = onThrow
        let size = NSSize(width: 56, height: 56)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y, width: size.width, height: size.height),
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
        contentView = SnowballDrawView(frame: NSRect(origin: .zero, size: size))
    }

    func show() {
        orderFrontRegardless()
    }

    override func mouseDown(with event: NSEvent) {
        onThrow()
        close()
    }
}

private final class SnowballDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 40, height: 40))
        ctx.setFillColor(red: 0.75, green: 0.85, blue: 0.95, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 16, y: 28, width: 12, height: 8))
    }
}

private final class SnowballFlightPanel: NSPanel {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private let duration: TimeInterval = 0.6
    private let from: CGPoint
    private let to: CGPoint
    private var flightView: SnowballFlightView?
    private var onClose: (() -> Void)?

    init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
        let size = NSSize(width: 260, height: 160)
        let origin = CGPoint(x: min(from.x, to.x) - 40, y: min(from.y, to.y) - 40)
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height),
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
        let v = SnowballFlightView(frame: NSRect(origin: .zero, size: size), from: CGPoint(x: from.x - origin.x, y: from.y - origin.y), to: CGPoint(x: to.x - origin.x, y: to.y - origin.y))
        self.flightView = v
        contentView = v
    }

    func show(duration: TimeInterval, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0 / 60.0
            self.flightView?.progress = min(1.0, self.elapsed / duration)
            self.flightView?.needsDisplay = true
            if self.elapsed >= duration {
                t.invalidate()
                self.close()
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClose?()
        onClose = nil
    }
}

private final class SnowballFlightView: NSView {
    var progress: Double = 0
    private let from: CGPoint
    private let to: CGPoint

    init(frame: NSRect, from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        self.from = .zero
        self.to = .zero
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let p = CGFloat(progress)
        let cur = CGPoint(x: from.x + (to.x - from.x) * p, y: from.y + (to.y - from.y) * p + sin(p * .pi) * 40)
        ctx.setFillColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cur.x - 10, y: cur.y - 10, width: 20, height: 20))
    }
}

// MARK: - 얼음 미끄럼틀

private final class IceSlidePanel: NSPanel {
    private let onSlide: () -> Void

    init(at pos: CGPoint, onSlide: @escaping () -> Void) {
        self.onSlide = onSlide
        let size = NSSize(width: 220, height: 80)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y - 10, width: size.width, height: size.height),
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
        contentView = IceSlideDrawView(frame: NSRect(origin: .zero, size: size))
    }

    func show() {
        orderFrontRegardless()
    }

    override func mouseDown(with event: NSEvent) {
        onSlide()
    }
}

private final class IceSlideDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.55, green: 0.82, blue: 0.96, alpha: 0.95)
        ctx.beginPath()
        ctx.addPath(CGPath(roundedRect: CGRect(x: 6, y: 14, width: 208, height: 44), cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 0.9)
        ctx.fill(CGRect(x: 20, y: 40, width: 180, height: 6))
        let label = "🧊 미끄럼틀 타기!" as NSString
        label.draw(at: NSPoint(x: 50, y: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.white])
    }
}

// MARK: - 별똥별

private final class ShootingStarPanel: NSPanel {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private var starView: ShootingStarDrawView?
    private let onWish: () -> Void

    init(at pos: CGPoint, onWish: @escaping () -> Void) {
        self.onWish = onWish
        let size = NSSize(width: 220, height: 220)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y - 60, width: size.width, height: size.height),
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
        let v = ShootingStarDrawView(frame: NSRect(origin: .zero, size: size))
        self.starView = v
        contentView = v
    }

    func show() {
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self, let v = self.starView else { t.invalidate(); return }
            self.elapsed += 1.0 / 60.0
            v.progress = self.elapsed
            v.needsDisplay = true
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onWish()
        close()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class ShootingStarDrawView: NSView {
    var progress: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let t = CGFloat(progress * 60.0)
        let x = bounds.width - 20 - t * 2.0
        let y = bounds.height - 20 - t * 1.2
        let wrappedX = x < 20 ? bounds.width - 20 : x
        let wrappedY = y < 20 ? bounds.height - 20 : y
        ctx.setStrokeColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 0.8)
        ctx.setLineWidth(3)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: wrappedX + 40, y: wrappedY + 24))
        ctx.addLine(to: CGPoint(x: wrappedX, y: wrappedY))
        ctx.strokePath()
        let star = "⭐" as NSString
        star.draw(at: NSPoint(x: wrappedX - 12, y: wrappedY - 12), withAttributes: [.font: NSFont.systemFont(ofSize: 28)])
        let hint = "클릭: 소원 빌기!" as NSString
        hint.draw(at: NSPoint(x: 50, y: 10), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white])
    }
}

// MARK: - 대나무 발판 (3단 성장)

private final class BambooPanel: NSPanel {
    private var timer: Timer?
    private var stage: Int = 0
    private var ticks: Int = 0
    private var bambooView: BambooDrawView?
    private let onClimb: () -> Void

    init(at pos: CGPoint, onClimb: @escaping () -> Void) {
        self.onClimb = onClimb
        let size = NSSize(width: 100, height: 190)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y, width: size.width, height: size.height),
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
        let v = BambooDrawView(frame: NSRect(origin: .zero, size: size))
        self.bambooView = v
        contentView = v
    }

    func show() {
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.ticks += 1
            if self.stage < 3 && self.ticks % 2 == 0 {
                self.stage += 1
                self.bambooView?.stage = self.stage
                self.bambooView?.needsDisplay = true
                SoundAndEffectsManager.shared.play(.pop)
            }
            if self.ticks >= 12 {
                t.invalidate()
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClimb()
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class BambooDrawView: NSView {
    var stage: Int = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.30, green: 0.65, blue: 0.30, alpha: 1.0)
        let segs = max(1, stage + 1)
        for i in 0..<segs {
            let y = 20 + i * 44
            if y + 40 <= Int(bounds.height) {
                ctx.fill(CGRect(x: 40, y: CGFloat(y), width: 20, height: 38))
                ctx.setFillColor(red: 0.22, green: 0.50, blue: 0.22, alpha: 1.0)
                ctx.fill(CGRect(x: 40, y: CGFloat(y), width: 20, height: 5))
                ctx.setFillColor(red: 0.30, green: 0.65, blue: 0.30, alpha: 1.0)
            }
        }
        let label = "🎍 \(stage + 1)단! 클릭: 올라가기" as NSString
        label.draw(at: NSPoint(x: 2, y: 2), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.white])
    }
}

// MARK: - 캠프 요리 (5초 조리)

private final class CampCookPanel: NSPanel {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private let cookDuration: TimeInterval = 5.0
    private var cookView: CampCookDrawView?
    private let onHint: () -> Void
    private let onDone: (CGPoint) -> Void
    private var didFinishSound = false

    init(at pos: CGPoint, onHint: @escaping () -> Void, onDone: @escaping (CGPoint) -> Void) {
        self.onHint = onHint
        self.onDone = onDone
        let size = NSSize(width: 150, height: 130)
        super.init(
            contentRect: NSRect(x: pos.x - size.width / 2.0, y: pos.y, width: size.width, height: size.height),
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
        let v = CampCookDrawView(frame: NSRect(origin: .zero, size: size))
        self.cookView = v
        contentView = v
    }

    func show() {
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 0.1
            let done = self.elapsed >= self.cookDuration
            self.cookView?.progress = min(1.0, self.elapsed / self.cookDuration)
            self.cookView?.needsDisplay = true
            if done && !self.didFinishSound {
                self.didFinishSound = true
                SoundAndEffectsManager.shared.play(.chime)
                RewardCenter.say("🍳 완성! 클릭해서 먹기!")
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private var isDone: Bool { elapsed >= cookDuration }

    override func mouseDown(with event: NSEvent) {
        if isDone {
            let pos = CGPoint(x: frame.midX, y: frame.maxY)
            onDone(pos)
            close()
        } else {
            onHint()
            SoundAndEffectsManager.shared.play(.splash)
        }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class CampCookDrawView: NSView {
    var progress: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 0.95)
        ctx.beginPath()
        ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
        let done = progress >= 1.0
        let pan = done ? "🍳" : "🍲" as NSString
        pan.draw(at: NSPoint(x: 56, y: 60), withAttributes: [.font: NSFont.systemFont(ofSize: 36)])
        let sizzle = done ? "완성! 클릭!" : "지글지글... \(Int(progress * 100))%"
        (sizzle as NSString).draw(at: NSPoint(x: 22, y: 34), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white])
        ctx.setFillColor(red: 0.95, green: 0.70, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: 16, y: 14, width: CGFloat(progress) * 118.0, height: 8))
    }
}
