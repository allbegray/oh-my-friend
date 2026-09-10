import AppKit
import CoreGraphics
import Foundation

// 12차 소셜 백로그: 포옹·악수·보물지도·기념사진 + SocialManager.
// RewardCenter 브리지(friendPos/playerPos/onReward)만 사용, UserDefaults 미사용.

public final class SocialManager {
    public static let shared = SocialManager()

    private var affection: Int = 0
    private var hugCooldownUntil: Date = .distantPast
    private var retained: [NSPanel] = []

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🫂 포옹하기" }, { [weak self] in self?.runHug() }),
            ExtraMenuEntry({ [weak self] in "🤝 악수하기 (호감도: \(self?.affection ?? 0))" }, { [weak self] in self?.runHandshake() }),
            ExtraMenuEntry({ "🕵️ 보물 지도" }, { [weak self] in self?.runTreasureMap() }),
            ExtraMenuEntry({ "🤳 기념사진" }, { [weak self] in self?.runPhoto() })
        ]
    }

    // MARK: - 공용

    private func friendOrMe() -> (pos: CGPoint, hasFriend: Bool) {
        if let f = RewardCenter.friendPos?() {
            return (f, true)
        }
        return (RewardCenter.me(), false)
    }

    private func keep(_ panel: NSPanel) {
        retained.append(panel)
    }

    private func release(_ panel: NSPanel) {
        retained.removeAll { $0 === panel }
    }

    private func toast(_ message: String, at pos: CGPoint, duration: TimeInterval = 2.0) {
        let panel = SocialToastPanel(message: message, at: pos)
        keep(panel)
        panel.show(duration: duration) { [weak self, weak panel] in
            guard let p = panel else { return }
            self?.release(p)
        }
    }

    // MARK: - 1. 포옹

    private func runHug() {
        let now = Date()
        if now < hugCooldownUntil {
            RewardCenter.say("🫂 잠시 쉬는 중…")
            return
        }
        hugCooldownUntil = now.addingTimeInterval(8.0)
        let target = friendOrMe()
        let panel = HugBurstPanel(at: target.pos)
        keep(panel)
        panel.show(duration: 2.0) { [weak self, weak panel] in
            guard let p = panel else { return }
            self?.release(p)
        }
        if target.hasFriend {
            RewardCenter.grant(xp: 2, "🫂 포옹!")
        } else {
            RewardCenter.grant(xp: 2, "🤗 셀프 허그!")
        }
    }

    // MARK: - 2. 악수

    private func runHandshake() {
        let me = RewardCenter.me()
        let friend = RewardCenter.friendPos?() ?? me
        let mid = CGPoint(x: (me.x + friend.x) / 2.0, y: (me.y + friend.y) / 2.0 + 40)
        affection += 1
        let panel = SocialToastPanel(message: "🤝 악수!", at: mid)
        keep(panel)
        panel.show(duration: 2.0) { [weak self, weak panel] in
            guard let p = panel else { return }
            self?.release(p)
        }
        RewardCenter.grant(xp: 2, "🤝 거래 성사! 호감도 상승!")
    }

    // MARK: - 3. 보물 지도

    private func runTreasureMap() {
        let me = RewardCenter.me()
        let mapPanel = TreasureMapPanel(at: me)
        keep(mapPanel)
        mapPanel.show(duration: 3.0) { [weak self, weak mapPanel] in
            guard let self = self, let mp = mapPanel else { return }
            self.release(mp)
            self.spawnTreasureX(from: me)
        }
        RewardCenter.say("🕵️ 오래된 지도를 펼쳤다!")
    }

    private func spawnTreasureX(from origin: CGPoint) {
        let dx = CGFloat.random(in: 180...320) * (Bool.random() ? 1 : -1)
        let dy = CGFloat.random(in: 60...200) * (Bool.random() ? 1 : -1)
        let xPos = CGPoint(x: origin.x + dx, y: origin.y + dy)
        let xPanel = TreasureXPanel(at: xPos) { [weak self] in
            guard let self = self else { return }
            self.digTreasure(at: xPos)
        }
        keep(xPanel)
        xPanel.show()
        // X 마크 정리용 참조 해제: 발굴 시 release, 30초 후에도 남아있으면 정리
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self, weak xPanel] in
            guard let self = self, let xp = xPanel, self.retained.contains(where: { $0 === xp }) else { return }
            xp.close()
            self.release(xp)
        }
    }

    private func digTreasure(at pos: CGPoint) {
        // 기존 X 마크 정리
        for p in retained.compactMap({ $0 as? TreasureXPanel }) {
            p.close()
            release(p)
        }
        let loots = ["💎 다이아 발견!", "🪙 금화 가득!", "💚 에메랄드 발견!"]
        let loot = loots.randomElement() ?? "💎 다이아 발견!"
        let dig = DigBurstPanel(at: pos)
        keep(dig)
        dig.show(duration: 1.5) { [weak self, weak dig] in
            guard let d = dig else { return }
            self?.release(d)
            self?.toast("📦 \(loot)", at: pos, duration: 2.0)
            RewardCenter.grant(xp: 6, "📦 \(loot)")
        }
        RewardCenter.say("⛏️ 퍽퍽! 발굴 중…")
    }

    // MARK: - 4. 기념사진

    private func runPhoto() {
        let me = RewardCenter.me()
        let flash = PhotoFlashPanel(at: me)
        keep(flash)
        flash.show(duration: 0.3) { [weak self, weak flash] in
            guard let f = flash else { return }
            self?.release(f)
        }
        RewardCenter.say("📸 찰칵! 포즈!")
        saveScreenshotAsync()
        RewardCenter.grant(xp: 2, "🤳 기념사진!")
    }

    private func saveScreenshotAsync() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let pictures = fm.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
            try? fm.createDirectory(at: pictures, withIntermediateDirectories: true)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd-HHmmss"
            let name = "OhMyFriend-\(fmt.string(from: Date())).png"
            let url = pictures.appendingPathComponent(name)
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-x", url.path]
            let errPipe = Pipe()
            proc.standardError = errPipe
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        RewardCenter.say("📸 저장 실패! Pictures 폴더 확인")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    RewardCenter.say("📸 저장 실패! Pictures 폴더 확인")
                }
            }
        }
    }
}

// MARK: - 토스트 팝업

private final class SocialToastPanel: NSPanel {
    private let message: String
    private var onClose: (() -> Void)?

    init(message: String, at pos: CGPoint) {
        self.message = message
        let size = NSSize(width: 230, height: 56)
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
        contentView = SocialToastDrawView(frame: NSRect(origin: .zero, size: size), message: message)
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

private final class SocialToastDrawView: NSView {
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
        ctx.setFillColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.86)
        let r: CGFloat = 12
        ctx.beginPath()
        ctx.addPath(CGPath(roundedRect: bounds, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.fillPath()
        let text = message as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        let tsize = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (bounds.width - tsize.width) / 2.0, y: (bounds.height - tsize.height) / 2.0), withAttributes: attrs)
    }
}

// MARK: - 포옹 하트 폭발

private final class HugBurstPanel: NSPanel {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private let duration: TimeInterval = 2.0
    private var burstView: HugBurstView?
    private var onClose: (() -> Void)?

    init(at pos: CGPoint) {
        let size = NSSize(width: 160, height: 160)
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
        let v = HugBurstView(frame: NSRect(origin: .zero, size: size))
        self.burstView = v
        contentView = v
    }

    func show(duration: TimeInterval = 2.0, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0 / 60.0
            self.burstView?.progress = min(1.0, self.elapsed / duration)
            self.burstView?.needsDisplay = true
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

private final class HugBurstView: NSView {
    var progress: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        let hearts = ["❤️", "❤️", "❤️", "❤️", "❤️"]
        let xs: [CGFloat] = [30, 55, 75, 95, 118]
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 22)]
        for (i, h) in hearts.enumerated() {
            let phase = min(1.0, max(0.0, progress * 1.2 - Double(i) * 0.05))
            let rise = CGFloat(phase) * 90.0
            let alpha = 1.0 - CGFloat(phase)
            let s = NSAttributedString(string: h, attributes: attrs)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(max(0, alpha))
            s.draw(at: NSPoint(x: xs[i], y: 20 + rise + CGFloat(sin(progress * 6.0 + Double(i))) * 4.0))
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}

// MARK: - 보물 지도 / X 마크 / 발굴

private final class TreasureMapPanel: NSPanel {
    private var onClose: (() -> Void)?

    init(at pos: CGPoint) {
        let size = NSSize(width: 200, height: 150)
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
        contentView = TreasureMapDrawView(frame: NSRect(origin: .zero, size: size))
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

private final class TreasureMapDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.93, green: 0.85, blue: 0.64, alpha: 0.96)
        ctx.fill(CGRect(x: 10, y: 10, width: 180, height: 130))
        ctx.setStrokeColor(red: 0.55, green: 0.38, blue: 0.20, alpha: 1.0)
        ctx.setLineWidth(3)
        ctx.stroke(CGRect(x: 10, y: 10, width: 180, height: 130))
        ctx.setStrokeColor(red: 0.70, green: 0.50, blue: 0.30, alpha: 1.0)
        ctx.setLineWidth(2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 30, y: 100))
        ctx.addLine(to: CGPoint(x: 70, y: 70))
        ctx.addLine(to: CGPoint(x: 55, y: 45))
        ctx.addLine(to: CGPoint(x: 120, y: 60))
        ctx.strokePath()
        let x = "❌" as NSString
        x.draw(at: NSPoint(x: 118, y: 52), withAttributes: [.font: NSFont.systemFont(ofSize: 22)])
        let label = "🕵️ 보물 지도" as NSString
        label.draw(at: NSPoint(x: 45, y: 112), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.black])
    }
}

private final class TreasureXPanel: NSPanel {
    private let onDig: () -> Void

    init(at pos: CGPoint, onDig: @escaping () -> Void) {
        self.onDig = onDig
        let size = NSSize(width: 72, height: 72)
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
        contentView = TreasureXDrawView(frame: NSRect(origin: .zero, size: size))
    }

    func show() {
        orderFrontRegardless()
    }

    override func mouseDown(with event: NSEvent) {
        onDig()
    }
}

private final class TreasureXDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let blink = (Int(Date().timeIntervalSince1970 * 2.0) % 2 == 0) ? 1.0 : 0.55
        ctx.setFillColor(red: 0.85, green: 0.20, blue: 0.20, alpha: CGFloat(blink))
        ctx.setLineWidth(8)
        ctx.setStrokeColor(red: 0.85, green: 0.20, blue: 0.20, alpha: CGFloat(blink))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 18, y: 18))
        ctx.addLine(to: CGPoint(x: 54, y: 54))
        ctx.move(to: CGPoint(x: 54, y: 18))
        ctx.addLine(to: CGPoint(x: 18, y: 54))
        ctx.strokePath()
    }
}

private final class DigBurstPanel: NSPanel {
    private var timer: Timer?
    private var elapsed: TimeInterval = 0
    private var digView: DigBurstView?
    private var onClose: (() -> Void)?

    init(at pos: CGPoint) {
        let size = NSSize(width: 140, height: 120)
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
        let v = DigBurstView(frame: NSRect(origin: .zero, size: size))
        self.digView = v
        contentView = v
    }

    func show(duration: TimeInterval = 1.5, onClose: (() -> Void)? = nil) {
        self.onClose = onClose
        orderFrontRegardless()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.elapsed += 1.0 / 60.0
            self.digView?.progress = min(1.0, self.elapsed / duration)
            self.digView?.needsDisplay = true
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

private final class DigBurstView: NSView {
    var progress: Double = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 흙 파티클
        ctx.setFillColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 1.0)
        let n = 14
        for i in 0..<n {
            let fx = CGFloat((i * 37) % 120) + 10
            let rise = CGFloat(progress) * 70.0 + CGFloat((i * 13) % 20)
            ctx.fill(CGRect(x: fx, y: 20 + rise, width: 7, height: 7))
        }
        let chest = "📦" as NSString
        chest.draw(at: NSPoint(x: 52, y: 8), withAttributes: [.font: NSFont.systemFont(ofSize: 36)])
    }
}

// MARK: - 기념사진 플래시

private final class PhotoFlashPanel: NSPanel {
    private var onClose: (() -> Void)?

    init(at pos: CGPoint) {
        let size = NSSize(width: 320, height: 240)
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
        contentView = PhotoFlashDrawView(frame: NSRect(origin: .zero, size: size))
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

private final class PhotoFlashDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.92)
        ctx.fill(bounds)
    }
}
