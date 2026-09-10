import AppKit
import CoreGraphics
import SceneKit

// 13차 백로그: 레드스톤 5종(레버·램프 / 음표 블록 / 그림 액자 / 배너 염료 / 트립와이어).
// RedstoneManager.shared.entries()로 메뉴에 연결한다.

public final class RedstoneManager {
    public static let shared = RedstoneManager()
    private init() {}

    private var leverWindow: RS13LeverWindow?
    private var lampWindow: RS13LampWindow?
    private var isLeverOn = false
    private var didCompleteCircuit = false

    private var noteWindow: RS13NoteBlockWindow?
    private var noteCount = 0
    private var noteIndex = 0
    private let scaleNames = ["도", "레", "미", "파", "솔", "라", "시", "도'"]
    private let scaleSounds: [SoundEffect] = [.pop, .jump, .heart, .chime, .alert, .splash, .whoosh, .portal]

    private var paintingWindow: RS13PaintingWindow?
    private var paintingIndex = 0

    private var bannerWindow: RS13BannerWindow?
    private var bannerTimer: Timer?

    private var tripWindow: RS13TripwireWindow?
    private var tripArmed = false
    private var tripLampWindow: RS13AlarmLampWindow?

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🔴 레버 당기기" }, { [weak self] in self?.spawnLever() }),
            ExtraMenuEntry({ [weak self] in "🎼 음표 블록 (\(self?.noteCount ?? 0)♪)" }, { [weak self] in self?.spawnNoteBlock() }),
            ExtraMenuEntry({ "🖼️ 그림 걸기" }, { [weak self] in self?.spawnPainting() }),
            ExtraMenuEntry({ "🚩 배너 염색" }, { [weak self] in self?.askDyeAndSpawnBanner() }),
            ExtraMenuEntry({ [weak self] in
                (self?.tripArmed == true) ? "🪝 트립와이어 (무장중…)" : "🪝 트립와이어"
            }, { [weak self] in self?.spawnTripwire() }),
        ]
    }

    // MARK: - 1. 레버 + 램프

    private func spawnLever() {
        leverWindow?.close()
        lampWindow?.close()
        let me = RewardCenter.me()
        let lever = RS13LeverWindow(
            floorPos: CGPoint(x: me.x - 70, y: me.y),
            isOn: isLeverOn,
            onToggle: { [weak self] in self?.toggleLever() }
        )
        let lamp = RS13LampWindow(
            floorPos: CGPoint(x: me.x + 70, y: me.y + 10),
            isLit: isLeverOn
        )
        leverWindow = lever
        lampWindow = lamp
        lever.place()
        lamp.place()
        RewardCenter.say(isLeverOn ? "🔴 레버 ON!" : "⬛ 레버 OFF…")
    }

    private func toggleLever() {
        isLeverOn.toggle()
        leverWindow?.isOn = isLeverOn
        lampWindow?.isLit = isLeverOn
        if isLeverOn {
            SoundAndEffectsManager.shared.play(.pop)
            if !didCompleteCircuit {
                didCompleteCircuit = true
                SoundAndEffectsManager.shared.play(.chime)
                RewardCenter.grant(xp: 2, "💡 회로 완성!")
            } else {
                RewardCenter.say("💡 불 켜졌다!")
            }
        } else {
            SoundAndEffectsManager.shared.play(.splash)
            RewardCenter.say("🌑 불 꺼졌다…")
        }
    }

    // MARK: - 2. 음표 블록

    private func spawnNoteBlock() {
        if noteWindow == nil {
            let me = RewardCenter.me()
            let w = RS13NoteBlockWindow(
                floorPos: CGPoint(x: me.x, y: me.y),
                noteName: scaleNames[noteIndex % scaleNames.count],
                onHit: { [weak self] in self?.hitNoteBlock() }
            )
            noteWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.noteWindow = nil }
        }
        hitNoteBlock()
    }

    private func hitNoteBlock() {
        let idx = noteIndex % scaleNames.count
        SoundAndEffectsManager.shared.play(scaleSounds[idx % scaleSounds.count])
        noteCount += 1
        noteIndex += 1
        noteWindow?.noteName = scaleNames[noteIndex % scaleNames.count]
        noteWindow?.pulse()
        RewardCenter.say("🎵 \(scaleNames[idx])!")
    }

    // MARK: - 3. 그림 액자

    private func spawnPainting() {
        if paintingWindow == nil {
            let me = RewardCenter.me()
            let w = RS13PaintingWindow(
                floorPos: CGPoint(x: me.x, y: me.y + 20),
                index: paintingIndex,
                onNext: { [weak self] in self?.nextPainting() }
            )
            paintingWindow = w
            w.place()
            w.onClosed = { [weak self] in self?.paintingWindow = nil }
            SoundAndEffectsManager.shared.play(.pop)
            RewardCenter.say("🖼️ 명화 전시!")
        } else {
            nextPainting()
        }
    }

    private func nextPainting() {
        paintingIndex = (paintingIndex + 1) % 3
        paintingWindow?.index = paintingIndex
        paintingWindow?.flip()
        SoundAndEffectsManager.shared.play(.whoosh)
    }

    // MARK: - 4. 배너 염료

    private func askDyeAndSpawnBanner() {
        let alert = NSAlert()
        alert.messageText = "🚩 배너 염색"
        alert.informativeText = "꽃 염료를 골라 배너를 물들이세요."
        alert.addButton(withTitle: "🌹 빨강")
        alert.addButton(withTitle: "💙 파랑")
        alert.addButton(withTitle: "🌼 노랑")
        alert.addButton(withTitle: "🌿 초록")
        let resp = alert.runModal()
        let dye: NSColor
        let dyeName: String
        switch resp {
        case .alertFirstButtonReturn:
            dye = NSColor.systemRed; dyeName = "빨강"
        case .alertSecondButtonReturn:
            dye = NSColor.systemBlue; dyeName = "파랑"
        case .alertThirdButtonReturn:
            dye = NSColor.systemYellow; dyeName = "노랑"
        default:
            dye = NSColor.systemGreen; dyeName = "초록"
        }
        let patterns = ["십자", "줄무늬", "테두리"]
        let pattern = patterns[Int.random(in: 0..<patterns.count)]
        bannerWindow?.close()
        bannerTimer?.invalidate()
        bannerTimer = nil
        let me = RewardCenter.me()
        let w = RS13BannerWindow(floorPos: CGPoint(x: me.x, y: me.y), dye: dye, pattern: pattern)
        bannerWindow = w
        w.place()
        SoundAndEffectsManager.shared.play(.chime)
        RewardCenter.grant(xp: 2, "🚩 \(dyeName) \(pattern) 배너!")
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.bannerWindow?.close()
            self?.bannerWindow = nil
            self?.bannerTimer?.invalidate()
            self?.bannerTimer = nil
        }
        if let t = bannerTimer { RunLoop.main.add(t, forMode: .common) }
    }

    // MARK: - 5. 트립와이어

    private func spawnTripwire() {
        if tripArmed {
            RewardCenter.say("🪝 이미 무장됨… 건드리면 울린다!")
            return
        }
        tripWindow?.close()
        let me = RewardCenter.me()
        let w = RS13TripwireWindow(
            floorPos: CGPoint(x: me.x, y: me.y),
            onTrip: { [weak self] in self?.fireTripwire() }
        )
        tripWindow = w
        tripArmed = true
        w.place()
        SoundAndEffectsManager.shared.play(.pop)
        RewardCenter.say("🪝 트립와이어 설치!")
    }

    private func fireTripwire() {
        guard tripArmed else { return }
        tripArmed = false
        SoundAndEffectsManager.shared.play(.chime)
        let me = RewardCenter.me()
        tripLampWindow?.close()
        let lamp = RS13AlarmLampWindow(floorPos: CGPoint(x: me.x + 90, y: me.y + 10))
        tripLampWindow = lamp
        lamp.place()
        RewardCenter.grant(xp: 2, "🚨 침입자 경보!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.tripLampWindow?.close()
            self?.tripLampWindow = nil
            self?.tripWindow?.close()
            self?.tripWindow = nil
        }
    }
}

// MARK: - 레버 패널

private final class RS13LeverWindow: EntityWindow {
    var isOn: Bool { didSet { drawView?.isOn = isOn; drawView?.needsDisplay = true } }
    private let onToggle: () -> Void
    private var drawView: RS13LeverDrawView?

    init(floorPos: CGPoint, isOn: Bool, onToggle: @escaping () -> Void) {
        self.isOn = isOn
        self.onToggle = onToggle
        let size = NSSize(width: 64, height: 72)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let v = RS13LeverDrawView(frame: NSRect(origin: .zero, size: size))
        v.isOn = isOn
        drawView = v
        contentView = v
    }

    func place() { orderFrontRegardless() }

    override func mouseDown(with event: NSEvent) { onToggle() }
}

private final class RS13LeverDrawView: NSView {
    var isOn = false
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 14, y: 0, width: 28, height: 10))
        ctx.setFillColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 3, y: 8, width: 6, height: 30))
        let hx = isOn ? w / 2 + 12 : w / 2 - 12
        ctx.setFillColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: hx - 7, y: isOn ? 38 : 30, width: 14, height: 14))
        ctx.setFillColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0)
        ctx.fill(CGRect(x: min(w / 2, hx) - 2, y: 36, width: abs(hx - w / 2) + 4, height: 4))
        let label = NSAttributedString(
            string: isOn ? "ON" : "OFF",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: isOn ? NSColor.systemRed : NSColor.secondaryLabelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 12, y: 52))
    }
}

// MARK: - 램프 패널

private final class RS13LampWindow: EntityWindow {
    var isLit: Bool { didSet { drawView?.isLit = isLit; drawView?.needsDisplay = true } }
    private var drawView: RS13LampDrawView?

    init(floorPos: CGPoint, isLit: Bool) {
        self.isLit = isLit
        let size = NSSize(width: 64, height: 72)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: true)
        let v = RS13LampDrawView(frame: NSRect(origin: .zero, size: size))
        v.isLit = isLit
        drawView = v
        contentView = v
    }

    func place() { orderFrontRegardless() }
}

private final class RS13LampDrawView: NSView {
    var isLit = false
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        if isLit {
            ctx.setFillColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.35)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: w - 4, height: 60))
        }
        ctx.setFillColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 16, y: 8, width: 32, height: 32))
        if isLit {
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        } else {
            ctx.setFillColor(red: 0.5, green: 0.42, blue: 0.3, alpha: 1.0)
        }
        ctx.fill(CGRect(x: w / 2 - 12, y: 12, width: 24, height: 24))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: isLit ? 0.9 : 0.25)
        ctx.fill(CGRect(x: w / 2 - 12, y: 26, width: 24, height: 4))
        let label = NSAttributedString(
            string: isLit ? "💡" : "🔲",
            attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 10, y: 42))
    }
}

// MARK: - 음표 블록

private final class RS13NoteBlockWindow: EntityWindow {
    var noteName: String { didSet { noteLabel?.stringValue = "♪ \(noteName)" } }
    var onClosed: (() -> Void)?
    private let onHit: () -> Void
    private var sceneView: MobSceneView?
    private var rig: CubeRig?
    private var noteLabel: NSTextField?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, noteName: String, onHit: @escaping () -> Void) {
        self.noteName = noteName
        self.onHit = onHit
        let size = NSSize(width: 72, height: 80)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let v = MobSceneView(frame: NSRect(origin: .zero, size: size))
        let r = CubeRig(color: .rgb(0.5, 0.35, 0.2), size: 1.0)
        let lid = vbox(1.02, 0.14, 1.02, .rgb(0.15, 0.12, 0.12))
        lid.position = SCNVector3(0, 0.55, 0)
        r.cube.addChildNode(lid)
        r.addTo(v.scene!, scale: 0.85)
        v.setSubject(r)
        let label = NSTextField(labelWithString: "♪ \(noteName)")
        label.font = NSFont.boldSystemFont(ofSize: 17)
        label.textColor = NSColor.systemPurple
        label.alignment = .center
        label.frame = NSRect(x: 0, y: size.height - 26, width: size.width, height: 22)
        v.addSubview(label)
        self.rig = r
        self.sceneView = v
        self.noteLabel = label
        v.onTap = { [weak self] in self?.onHit() }
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
        rig?.squash(1.0)
        noteLabel?.font = NSFont.boldSystemFont(ofSize: 24)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.rig?.squash(0)
            self?.noteLabel?.font = NSFont.boldSystemFont(ofSize: 17)
        }
    }

    override func mouseDown(with event: NSEvent) { onHit() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

// MARK: - 그림 액자

private final class RS13PaintingWindow: EntityWindow {
    var index: Int { didSet { drawView?.index = index; drawView?.needsDisplay = true } }
    var onClosed: (() -> Void)?
    private let onNext: () -> Void
    private var drawView: RS13PaintingDrawView?
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, index: Int, onNext: @escaping () -> Void) {
        self.index = index
        self.onNext = onNext
        let size = NSSize(width: 96, height: 72)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        let v = RS13PaintingDrawView(frame: NSRect(origin: .zero, size: size))
        v.index = index
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

    func flip() {
        drawView?.flip = 0
        drawView?.needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) { onNext() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
        onClosed?()
    }
}

private final class RS13PaintingDrawView: NSView {
    var index = 0
    var flip: CGFloat = 1.0
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        let squeeze = max(0.15, abs(cos(flip * .pi / 2)))
        let iw = (w - 16) * squeeze
        let ix = (w - iw) / 2
        ctx.setFillColor(red: 0.4, green: 0.28, blue: 0.15, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 2, width: w - 4, height: h - 4))
        switch index % 3 {
        case 0:
            ctx.setFillColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 1.0)
            ctx.fill(CGRect(x: ix, y: 8, width: iw, height: h - 16))
            ctx.setFillColor(red: 0.2, green: 0.7, blue: 0.25, alpha: 1.0)
            ctx.fill(CGRect(x: ix + iw * 0.2, y: 16, width: iw * 0.6, height: (h - 16) * 0.7))
            ctx.setFillColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
            ctx.fill(CGRect(x: ix + iw * 0.3, y: h * 0.5, width: iw * 0.15, height: h * 0.18))
            ctx.fill(CGRect(x: ix + iw * 0.55, y: h * 0.5, width: iw * 0.15, height: h * 0.18))
        case 1:
            ctx.setFillColor(red: 0.15, green: 0.35, blue: 0.7, alpha: 1.0)
            ctx.fill(CGRect(x: ix, y: 8, width: iw, height: h - 16))
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: ix + iw * 0.32, y: h * 0.38, width: iw * 0.36, height: h * 0.3))
            ctx.setFillColor(red: 0.3, green: 0.6, blue: 0.2, alpha: 1.0)
            ctx.fill(CGRect(x: ix + iw * 0.46, y: 10, width: iw * 0.08, height: h * 0.35))
        default:
            ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            ctx.fill(CGRect(x: ix, y: 8, width: iw, height: h - 16))
            ctx.setFillColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: ix + iw * 0.28, y: h * 0.3, width: iw * 0.44, height: h * 0.42))
            ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: ix + iw * 0.36, y: h * 0.45, width: iw * 0.12, height: h * 0.14))
            ctx.fillEllipse(in: CGRect(x: ix + iw * 0.52, y: h * 0.45, width: iw * 0.12, height: h * 0.14))
        }
        if flip < 1.0 {
            flip = min(1.0, flip + 0.2)
            needsDisplay = true
        }
    }
}

// MARK: - 배너 미리보기

private final class RS13BannerWindow: EntityWindow {
    private let dye: NSColor
    private let pattern: String

    init(floorPos: CGPoint, dye: NSColor, pattern: String) {
        self.dye = dye
        self.pattern = pattern
        let size = NSSize(width: 72, height: 104)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: true)
        contentView = RS13BannerDrawView(frame: NSRect(origin: .zero, size: size), dye: dye, pattern: pattern)
    }

    func place() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }
}

private final class RS13BannerDrawView: NSView {
    private let dye: NSColor
    private let pattern: String

    init(frame: NSRect, dye: NSColor, pattern: String) {
        self.dye = dye
        self.pattern = pattern
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        ctx.setFillColor(red: 0.4, green: 0.3, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 3, y: 88, width: 30, height: 5))
        dye.setFill()
        ctx.fill(CGRect(x: w / 2 - 18, y: 8, width: 36, height: 82))
        NSColor.white.withAlphaComponent(0.85).setFill()
        switch pattern {
        case "십자":
            ctx.fill(CGRect(x: w / 2 - 18, y: 40, width: 36, height: 10))
            ctx.fill(CGRect(x: w / 2 - 5, y: 8, width: 10, height: 82))
        case "줄무늬":
            ctx.fill(CGRect(x: w / 2 - 18, y: 28, width: 36, height: 8))
            ctx.fill(CGRect(x: w / 2 - 18, y: 52, width: 36, height: 8))
            ctx.fill(CGRect(x: w / 2 - 18, y: 74, width: 36, height: 6))
        default:
            ctx.fill(CGRect(x: w / 2 - 18, y: 8, width: 36, height: 6))
            ctx.fill(CGRect(x: w / 2 - 18, y: 84, width: 36, height: 6))
            ctx.fill(CGRect(x: w / 2 - 18, y: 8, width: 5, height: 82))
            ctx.fill(CGRect(x: w / 2 + 13, y: 8, width: 5, height: 82))
        }
        let label = NSAttributedString(
            string: "🚩",
            attributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 8, y: 90))
    }
}

// MARK: - 트립와이어 + 경보 램프

private final class RS13TripwireWindow: EntityWindow {
    private let onTrip: () -> Void
    private var timer: Timer?
    private var elapsed: TimeInterval = 0

    init(floorPos: CGPoint, onTrip: @escaping () -> Void) {
        self.onTrip = onTrip
        let size = NSSize(width: 220, height: 40)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: false)
        contentView = RS13TripwireDrawView(frame: NSRect(origin: .zero, size: size))
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

    override func mouseDown(with event: NSEvent) { onTrip() }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class RS13TripwireDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        let h = bounds.height
        ctx.setFillColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 8, width: 8, height: 24))
        ctx.fill(CGRect(x: w - 12, y: 8, width: 8, height: 24))
        ctx.setStrokeColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: 12, y: h / 2))
        ctx.addLine(to: CGPoint(x: w - 12, y: h / 2))
        ctx.strokePath()
        let label = NSAttributedString(
            string: "🪝 무장중…",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 32, y: 2))
    }
}

private final class RS13AlarmLampWindow: EntityWindow {
    private var timer: Timer?
    private var blink = false
    private var ticks = 0
    private var drawView: RS13AlarmLampDrawView?

    init(floorPos: CGPoint) {
        let size = NSSize(width: 64, height: 64)
        super.init(contentRect: NSRect(x: floorPos.x - size.width / 2, y: floorPos.y, width: size.width, height: size.height), ignoresMouse: true)
        let v = RS13AlarmLampDrawView(frame: NSRect(origin: .zero, size: size))
        drawView = v
        contentView = v
    }

    func place() {
        orderFrontRegardless()
        timer?.invalidate()
        ticks = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.ticks += 1
            self.blink.toggle()
            self.drawView?.blink = self.blink
            self.drawView?.needsDisplay = true
            if self.ticks >= 12 {
                t.invalidate()
                self.timer = nil
                self.close()
            }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    override func close() {
        timer?.invalidate()
        timer = nil
        super.close()
    }
}

private final class RS13AlarmLampDrawView: NSView {
    var blink = false
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width
        if blink {
            ctx.setFillColor(red: 1.0, green: 0.2, blue: 0.15, alpha: 0.4)
            ctx.fillEllipse(in: CGRect(x: 2, y: 2, width: w - 4, height: 52))
        }
        ctx.setFillColor(red: blink ? 1.0 : 0.45, green: blink ? 0.15 : 0.12, blue: blink ? 0.12 : 0.12, alpha: 1.0)
        ctx.fill(CGRect(x: w / 2 - 13, y: 12, width: 26, height: 26))
        let label = NSAttributedString(
            string: "🚨",
            attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.labelColor]
        )
        label.draw(at: NSPoint(x: w / 2 - 10, y: 40))
    }
}
