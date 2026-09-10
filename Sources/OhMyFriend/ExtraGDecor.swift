import AppKit
import CoreGraphics
import Foundation

// G분야 장식 10종: 거치대·화분·양탄자·책장·모루·영혼랜턴·개구리불·스컬크센서·침대·지도벽 + DecorGManager.
// DecorGManager.shared.entries()로 "🎉 추가 모션" 서브메뉴에 연결한다. 기존 파일 무수정.

public final class DecorGManager {
    public static let shared = DecorGManager()

    private var gStand: GArmorStandWindow?
    private var gPots: [GFlowerPotWindow] = []
    private var gRug: GRugWindow?
    private var gShelves: [GBookshelfWindow] = []
    private var gAnvil: GAnvilWindow?
    private var gAnvilNameMemo = ""
    private var gLantern: GSoulLanternWindow?
    private var gFroglight: GFroglightWindow?
    private var gSensor: GSculkSensorWindow?
    private var gBed: GBedWindow?
    private var gMap: GMapWallWindow?

    private init() {}

    public func entries() -> [ExtraMenuEntry] {
        return [
            ExtraMenuEntry({ "🗿 갑옷 거치대" }, { [weak self] in self?.toggleGStand() }),
            ExtraMenuEntry({ "🪴 화분" }, { [weak self] in self?.toggleGPots() }),
            ExtraMenuEntry({ "🟥 양탄자" }, { [weak self] in self?.toggleGRug() }),
            ExtraMenuEntry({ "📚 책장" }, { [weak self] in self?.addGShelf() }),
            ExtraMenuEntry({ "⚒️ 모루" }, { [weak self] in self?.toggleGAnvil() }),
            ExtraMenuEntry({ "🏮 영혼 랜턴" }, { [weak self] in self?.toggleGLantern() }),
            ExtraMenuEntry({ "🐸 개구리불" }, { [weak self] in self?.toggleGFroglight() }),
            ExtraMenuEntry({ "📡 스컬크 센서" }, { [weak self] in self?.toggleGSensor() }),
            ExtraMenuEntry({ "🛏️ 침대 염색" }, { [weak self] in self?.toggleGBed() }),
            ExtraMenuEntry({ "🖼️ 지도 벽" }, { [weak self] in self?.toggleGMap() }),
        ]
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

    // MARK: - 🗿 갑옷 거치대

    public func toggleGStand() {
        if let w = gStand, w.isVisible {
            w.close(); gStand = nil; return
        }
        gStand = nil
        let w = GArmorStandWindow(startPos: spawnPos(dx: -80)) { [weak self] pose, weapon in
            self?.handleGStandTap(pose: pose, weapon: weapon)
        }
        gStand = w
        w.start()
    }

    private func handleGStandTap(pose: String, weapon: String) {
        RewardCenter.say("🗿 \(pose) + \(weapon)")
        SoundAndEffectsManager.shared.play(.pop)
    }

    // MARK: - 🪴 화분 (창문 화단 모드: 3개 배치)

    public func toggleGPots() {
        let alive = gPots.filter { $0.isVisible }
        if !alive.isEmpty {
            for w in gPots { w.close() }
            gPots.removeAll()
            return
        }
        gPots.removeAll()
        let base = spawnPos(dx: 0)
        for i in 0..<3 {
            let pos = CGPoint(x: base.x + CGFloat(i - 1) * 64, y: base.y)
            let w = GFlowerPotWindow(startPos: pos) { flower in
                RewardCenter.say("🪴 \(flower)로 교체!")
                SoundAndEffectsManager.shared.play(.pop)
            }
            gPots.append(w)
            w.start()
        }
        RewardCenter.say("🪴 창문 화단 완성! (클릭하면 꽃 교체)")
    }

    // MARK: - 🟥 양탄자

    public func toggleGRug() {
        if let w = gRug, w.isVisible {
            w.close(); gRug = nil; return
        }
        gRug = nil
        let w = GRugWindow(startPos: spawnPos(dx: 80)) { hidden in
            if hidden {
                RewardCenter.say("🙈 앗, 양탄자 어디갔지~?")
            } else {
                RewardCenter.say("🟥 짠! 양탄자 등장!")
            }
            SoundAndEffectsManager.shared.play(.pop)
        }
        gRug = w
        w.start()
    }

    // MARK: - 📚 책장 (최대 15개, 완성 시 인챈트 해금 +4XP)

    public func addGShelf() {
        gShelves = gShelves.filter { $0.isVisible }
        if gShelves.count >= 15 {
            for w in gShelves { w.close() }
            gShelves.removeAll()
            RewardCenter.say("📚 서재 정리 완료!")
            return
        }
        let base = spawnPos(dx: 0)
        let pos = CGPoint(x: base.x + CGFloat(gShelves.count % 5) * 52 - 104, y: base.y + CGFloat(gShelves.count / 5) * 56)
        let w = GBookshelfWindow(startPos: pos, seed: gShelves.count) {
            RewardCenter.say("📚 ...")
            SoundAndEffectsManager.shared.play(.pop)
        }
        gShelves.append(w)
        w.start()
        if gShelves.count >= 15 {
            RewardCenter.grant(xp: 4, "📚 인챈트 해금! 서재 완성!")
            SoundAndEffectsManager.shared.play(.chime)
        } else {
            RewardCenter.say("📚 책장 \(gShelves.count)/15")
        }
    }

    // MARK: - ⚒️ 모루 (클릭 수리 + 이름표 모드)

    public func toggleGAnvil() {
        if let w = gAnvil, w.isVisible {
            promptGAnvilName()
            return
        }
        gAnvil = nil
        let w = GAnvilWindow(startPos: spawnPos(dx: -40)) {
            RewardCenter.say("🔨 땡! 수리 완료!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        gAnvil = w
        w.start()
    }

    private func promptGAnvilName() {
        let alert = NSAlert()
        alert.messageText = "🏷️ 이름표 모드"
        alert.informativeText = "모루에 새길 이름을 입력하세요 (Manager 메모에 저장됩니다)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = gAnvilNameMemo
        alert.accessoryView = field
        alert.addButton(withTitle: "부착")
        alert.addButton(withTitle: "치우기")
        alert.addButton(withTitle: "취소")
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            gAnvilNameMemo = field.stringValue
            if gAnvilNameMemo.isEmpty {
                RewardCenter.say("🏷️ 이름이 비어 있어요!")
            } else {
                RewardCenter.say("🏷️ '\(gAnvilNameMemo)' 이름표 부착!")
                SoundAndEffectsManager.shared.play(.chime)
            }
        } else if resp == .alertSecondButtonReturn {
            gAnvil?.close()
            gAnvil = nil
        }
    }

    // MARK: - 🏮 영혼 랜턴 (파란 불꽃 + 퇴치 결계 + 밤 자동 점등)

    public func toggleGLantern() {
        if let w = gLantern, w.isVisible {
            w.close(); gLantern = nil; return
        }
        gLantern = nil
        let w = GSoulLanternWindow(startPos: spawnPos(dx: 40)) { lit in
            if lit {
                RewardCenter.say("🏮 퇴치 결계 ON! 몹 접근 금지!")
            } else {
                RewardCenter.say("🏮 랜턴 소등...")
            }
            SoundAndEffectsManager.shared.play(.pop)
        }
        gLantern = w
        w.start()
    }

    // MARK: - 🐸 개구리불 (3색 순환 조명)

    public func toggleGFroglight() {
        if let w = gFroglight, w.isVisible {
            w.close(); gFroglight = nil; return
        }
        gFroglight = nil
        let w = GFroglightWindow(startPos: spawnPos(dx: -120)) { colorName in
            RewardCenter.say("🐸 개구리불: \(colorName)!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        gFroglight = w
        w.start()
    }

    // MARK: - 📡 스컬크 센서 (클릭 진동 감지 + 딩동 + 감도 3단계)

    public func toggleGSensor() {
        if let w = gSensor, w.isVisible {
            w.close(); gSensor = nil; return
        }
        gSensor = nil
        let w = GSculkSensorWindow(startPos: spawnPos(dx: 120)) { level in
            RewardCenter.say("딩동~ 🔔 (감도 \(level)/3)")
            SoundAndEffectsManager.shared.play(.chime)
        }
        gSensor = w
        w.start()
    }

    // MARK: - 🛏️ 침대 (16색 순환 + 수면 연출 + 아침)

    public func toggleGBed() {
        if let w = gBed, w.isVisible {
            w.close(); gBed = nil; return
        }
        gBed = nil
        let w = GBedWindow(startPos: spawnPos(dx: 0)) { colorName in
            RewardCenter.say("🛏️ \(colorName) 침대! Zzz... ☀️ 좋은 아침!")
            SoundAndEffectsManager.shared.play(.pop)
        }
        gBed = w
        w.start()
    }

    // MARK: - 🖼️ 지도 벽 (9칸 채우기 + 완성 벽화 +5XP)

    public func toggleGMap() {
        if let w = gMap, w.isVisible {
            w.close(); gMap = nil; return
        }
        gMap = nil
        let w = GMapWallWindow(startPos: spawnPos(dx: 0)) { filled in
            if filled >= 9 {
                RewardCenter.grant(xp: 5, "🖼️ 대륙 벽화 완성!")
                SoundAndEffectsManager.shared.play(.chime)
            } else {
                RewardCenter.say("🖼️ 탐험 기록 \(filled)/9")
                SoundAndEffectsManager.shared.play(.pop)
            }
        }
        gMap = w
        w.start()
    }
}

// MARK: - 🗿 갑옷 거치대: 포즈 13종 순환 + 무기 4종 전시

public final class GArmorStandWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (String, String) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: GArmorStandDrawView?
    private let panelW: CGFloat = 72
    private let panelH: CGFloat = 84

    static let poses = ["기본", "인사", "경례", "웅크리기", "활시위", "돌진", "점프", "춤", "앉기", "눕기", "검들기", "방패들기", "승리"]
    static let weapons = ["🗡️", "⛏️", "🏹", "🔱"]
    var poseIndex = 0
    var weaponIndex = 0

    public init(startPos: CGPoint, onTap: @escaping (String, String) -> Void) {
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
        let view = GArmorStandDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        syncDraw()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.bob = sin(self.phase * 2.0) * 1.5
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    private func syncDraw() {
        drawView?.poseIndex = poseIndex
        drawView?.weapon = GArmorStandWindow.weapons[weaponIndex]
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        poseIndex = (poseIndex + 1) % GArmorStandWindow.poses.count
        if poseIndex == 0 {
            weaponIndex = (weaponIndex + 1) % GArmorStandWindow.weapons.count
        }
        syncDraw()
        onTap(GArmorStandWindow.poses[poseIndex], GArmorStandWindow.weapons[weaponIndex])
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class GArmorStandDrawView: NSView {
    var poseIndex = 0
    var weapon = "🗡️"
    var bob: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        let by = 6.0 + bob
        // 받침대
        ctx.setFillColor(red: 0.45, green: 0.38, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 20, y: by, width: 40, height: 5))
        // 기둥
        ctx.setFillColor(red: 0.55, green: 0.47, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 2, y: by + 5, width: 4, height: 46))
        // 머리 (호박 헬멧 느낌)
        ctx.setFillColor(red: 0.85, green: 0.60, blue: 0.15, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: cx - 8, y: by + 55, width: 16, height: 15))
        // 몸통 판
        ctx.setFillColor(red: 0.60, green: 0.52, blue: 0.42, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 7, y: by + 32, width: 14, height: 22))
        // 팔: 포즈 인덱스로 각도 변화
        let lift = CGFloat(poseIndex % 4) * 6.0
        let spread = CGFloat(poseIndex / 4) * 4.0
        ctx.setStrokeColor(red: 0.55, green: 0.47, blue: 0.38, alpha: 1.0)
        ctx.setLineWidth(4.0)
        let shoulderY = by + 48
        ctx.move(to: CGPoint(x: cx - 7, y: shoulderY))
        ctx.addLine(to: CGPoint(x: cx - 14 - spread, y: shoulderY - 8 - lift))
        ctx.move(to: CGPoint(x: cx + 7, y: shoulderY))
        ctx.addLine(to: CGPoint(x: cx + 14 + spread, y: shoulderY - 8 - lift))
        ctx.strokePath()
        // 다리
        ctx.move(to: CGPoint(x: cx - 4, y: by + 32))
        ctx.addLine(to: CGPoint(x: cx - 8, y: by + 5))
        ctx.move(to: CGPoint(x: cx + 4, y: by + 32))
        ctx.addLine(to: CGPoint(x: cx + 8, y: by + 5))
        ctx.strokePath()
        // 오른손 무기 emoji 전시
        let s = weapon as NSString
        s.draw(at: CGPoint(x: cx + 10 + spread, y: shoulderY - 14 - lift), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
    }
}

// MARK: - 🪴 화분: 꽃 16종 랜덤 전시 + 클릭 교체

public final class GFlowerPotWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (String) -> Void
    private var drawView: GFlowerPotDrawView?
    private let panelW: CGFloat = 48
    private let panelH: CGFloat = 64

    static let flowers = ["🌹", "🌷", "🌻", "🌼", "🌸", "💐", "🌺", "🪷", "🌾", "🍀", "🌵", "🎍", "🌲", "🌳", "🍄", "🥀"]
    var flower = "🌹"

    public init(startPos: CGPoint, onTap: @escaping (String) -> Void) {
        self.position = startPos
        self.onTap = onTap
        self.flower = GFlowerPotWindow.flowers.randomElement() ?? "🌹"
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
        let view = GFlowerPotDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        drawView?.flower = flower
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        var next = GFlowerPotWindow.flowers.randomElement() ?? "🌹"
        if next == flower {
            next = GFlowerPotWindow.flowers.randomElement() ?? "🌷"
        }
        flower = next
        drawView?.flower = flower
        drawView?.needsDisplay = true
        onTap(flower)
    }
}

private final class GFlowerPotDrawView: NSView {
    var flower = "🌹"

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 줄기
        ctx.setStrokeColor(red: 0.25, green: 0.55, blue: 0.25, alpha: 1.0)
        ctx.setLineWidth(3.0)
        ctx.move(to: CGPoint(x: cx, y: 26))
        ctx.addLine(to: CGPoint(x: cx, y: 40))
        ctx.strokePath()
        // 꽃 emoji 전시
        let s = flower as NSString
        s.draw(at: CGPoint(x: cx - 12, y: 36), withAttributes: [.font: NSFont.systemFont(ofSize: 22)])
        // 화분 몸통
        ctx.setFillColor(red: 0.65, green: 0.35, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 14, y: 6, width: 28, height: 20))
        // 화분 테두리
        ctx.setFillColor(red: 0.75, green: 0.42, blue: 0.24, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 16, y: 24, width: 32, height: 6))
    }
}

// MARK: - 🟥 양탄자: 바닥 패널 + 클릭 숨기기/보이기

public final class GRugWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (Bool) -> Void
    private var drawView: GRugDrawView?
    private let panelW: CGFloat = 170
    private let panelH: CGFloat = 64
    var hiddenRug = false

    public init(startPos: CGPoint, onTap: @escaping (Bool) -> Void) {
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
        let view = GRugDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        drawView?.hiddenRug = hiddenRug
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        hiddenRug.toggle()
        drawView?.hiddenRug = hiddenRug
        drawView?.needsDisplay = true
        onTap(hiddenRug)
    }
}

private final class GRugDrawView: NSView {
    var hiddenRug = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if hiddenRug {
            // 말아놓은 롤 + 장난 emoji
            ctx.setFillColor(red: 0.75, green: 0.20, blue: 0.20, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 8, y: 18, width: 34, height: 28))
            ctx.setFillColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 12, y: 24, width: 12, height: 16))
            let s = "🙈" as NSString
            s.draw(at: CGPoint(x: 52, y: 20), withAttributes: [.font: NSFont.systemFont(ofSize: 22)])
            return
        }
        // 펼친 양탄자
        ctx.setFillColor(red: 0.78, green: 0.18, blue: 0.18, alpha: 1.0)
        ctx.fill(CGRect(x: 10, y: 12, width: 150, height: 40))
        ctx.setStrokeColor(red: 0.95, green: 0.80, blue: 0.40, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.stroke(CGRect(x: 16, y: 18, width: 138, height: 28))
        // 중앙 무늬
        ctx.setFillColor(red: 0.95, green: 0.80, blue: 0.40, alpha: 1.0)
        ctx.fillEllipse(in: CGRect(x: 75, y: 24, width: 20, height: 16))
        // 술 장식
        ctx.setFillColor(red: 0.92, green: 0.85, blue: 0.70, alpha: 1.0)
        for xi in stride(from: 12, through: 154, by: 12) {
            let x = CGFloat(xi)
            ctx.fill(CGRect(x: x, y: 6, width: 4, height: 6))
            ctx.fill(CGRect(x: x, y: 52, width: 4, height: 6))
        }
    }
}

// MARK: - 📚 책장: 클릭당 1개씩 최대 15개

public final class GBookshelfWindow: NSPanel {
    public var position: CGPoint
    private let onTap: () -> Void
    private let seed: Int
    private var drawView: GBookshelfDrawView?
    private let panelW: CGFloat = 48
    private let panelH: CGFloat = 52

    public init(startPos: CGPoint, seed: Int, onTap: @escaping () -> Void) {
        self.position = startPos
        self.seed = seed
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
        let view = GBookshelfDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)), seed: seed)
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        onTap()
    }
}

private final class GBookshelfDrawView: NSView {
    private let seed: Int

    init(frame: NSRect, seed: Int) {
        self.seed = seed
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 나무 틀
        ctx.setFillColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 2, width: 44, height: 48))
        // 책등 3단
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.75, 0.25, 0.25), (0.25, 0.45, 0.75), (0.30, 0.65, 0.30),
            (0.80, 0.60, 0.20), (0.55, 0.35, 0.65), (0.85, 0.50, 0.30),
        ]
        for row in 0..<3 {
            let y = 6.0 + CGFloat(row) * 14.0
            var x: CGFloat = 5
            var k = seed * 3 + row
            while x < 40 {
                let w: CGFloat = 4 + CGFloat((k * 7 + row) % 3)
                let c = palette[(k + row) % palette.count]
                ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
                ctx.fill(CGRect(x: x, y: y, width: w, height: 11))
                x += w + 1
                k += 1
                if k > seed * 3 + row + 6 { break }
            }
        }
    }
}

// MARK: - ⚒️ 모루: 클릭 수리 연출

public final class GAnvilWindow: NSPanel {
    public var position: CGPoint
    private let onTap: () -> Void
    private var drawView: GAnvilDrawView?
    private let panelW: CGFloat = 76
    private let panelH: CGFloat = 60

    public init(startPos: CGPoint, onTap: @escaping () -> Void) {
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
        let view = GAnvilDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
    }

    public override func mouseDown(with event: NSEvent) {
        drawView?.sparkLeft = 0.8
        drawView?.needsDisplay = true
        onTap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.drawView?.needsDisplay = true
        }
    }
}

private final class GAnvilDrawView: NSView {
    var sparkLeft: TimeInterval = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 상판
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 34, width: 60, height: 12))
        ctx.fill(CGRect(x: 60, y: 37, width: 12, height: 6))
        // 허리
        ctx.setFillColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: 30, y: 16, width: 16, height: 18))
        // 받침
        ctx.setFillColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1.0)
        ctx.fill(CGRect(x: 20, y: 6, width: 36, height: 10))
        // 수리 불꽃
        if sparkLeft > 0 {
            sparkLeft -= 0.15
            ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: 32, y: 46, width: 6, height: 6))
            ctx.fillEllipse(in: CGRect(x: 44, y: 50, width: 4, height: 4))
            ctx.fillEllipse(in: CGRect(x: 24, y: 50, width: 3, height: 3))
            ctx.setStrokeColor(red: 1.0, green: 0.95, blue: 0.60, alpha: 1.0)
            ctx.setLineWidth(1.5)
            ctx.move(to: CGPoint(x: 38, y: 46))
            ctx.addLine(to: CGPoint(x: 46, y: 56))
            ctx.move(to: CGPoint(x: 38, y: 46))
            ctx.addLine(to: CGPoint(x: 28, y: 56))
            ctx.strokePath()
        }
    }
}

// MARK: - 🏮 영혼 랜턴: 파란 불꽃 + 밤 자동 점등

public final class GSoulLanternWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (Bool) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: GSoulLanternDrawView?
    private let panelW: CGFloat = 48
    private let panelH: CGFloat = 72
    private var manualLit: Bool?

    public init(startPos: CGPoint, onTap: @escaping (Bool) -> Void) {
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
        let view = GSoulLanternDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    private var isNight: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 18 || h < 6
    }

    private var lit: Bool {
        return manualLit ?? isNight
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        if lit {
            RewardCenter.say("🏮 밤이네요! 영혼 랜턴 자동 점등!")
        }
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.lit = self.lit
            self.drawView?.flick = sin(self.phase * 9.0) * 2.0
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        manualLit = !lit
        onTap(lit)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class GSoulLanternDrawView: NSView {
    var lit = false
    var flick: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 사슬
        ctx.setStrokeColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: cx, y: 68))
        ctx.addLine(to: CGPoint(x: cx, y: 58))
        ctx.strokePath()
        // 뚜껑 + 바닥
        ctx.setFillColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 12, y: 52, width: 24, height: 6))
        ctx.fill(CGRect(x: cx - 12, y: 12, width: 24, height: 6))
        // 유리
        ctx.setFillColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 0.9)
        ctx.fill(CGRect(x: cx - 10, y: 18, width: 20, height: 34))
        if lit {
            // 파란 불꽃
            let r = 7.0 + flick
            ctx.setFillColor(red: 0.35, green: 0.80, blue: 1.0, alpha: 0.35)
            ctx.fillEllipse(in: CGRect(x: cx - 12, y: 20, width: 24, height: 26))
            ctx.setFillColor(red: 0.30, green: 0.75, blue: 1.0, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: cx - r / 2, y: 28, width: r, height: r + 6))
            ctx.setFillColor(red: 0.85, green: 0.97, blue: 1.0, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: cx - 2.5, y: 30, width: 5, height: 7))
        } else {
            ctx.setFillColor(red: 0.30, green: 0.35, blue: 0.42, alpha: 1.0)
            ctx.fillEllipse(in: CGRect(x: cx - 4, y: 30, width: 8, height: 10))
        }
    }
}

// MARK: - 🐸 개구리불: 3색 순환 조명

public final class GFroglightWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (String) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var drawView: GFroglightDrawView?
    private let panelW: CGFloat = 56
    private let panelH: CGFloat = 56

    static let colors: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("진주", 0.95, 0.80, 0.90),
        ("버단트", 0.45, 0.90, 0.40),
        ("황토", 0.95, 0.70, 0.25),
    ]
    var colorIndex = 0

    public init(startPos: CGPoint, onTap: @escaping (String) -> Void) {
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
        let view = GFroglightDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        syncDraw()
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            self.drawView?.glow = 0.75 + sin(self.phase * 4.0) * 0.25
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    private func syncDraw() {
        let c = GFroglightWindow.colors[colorIndex]
        drawView?.color = (c.1, c.2, c.3)
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        colorIndex = (colorIndex + 1) % GFroglightWindow.colors.count
        syncDraw()
        onTap(GFroglightWindow.colors[colorIndex].0)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class GFroglightDrawView: NSView {
    var color: (CGFloat, CGFloat, CGFloat) = (0.95, 0.80, 0.90)
    var glow: CGFloat = 1.0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 후광
        ctx.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 0.25 * glow)
        ctx.fillEllipse(in: CGRect(x: cx - 24, y: 4, width: 48, height: 48))
        // 블록 본체
        ctx.setFillColor(red: color.0 * 0.7, green: color.1 * 0.7, blue: color.2 * 0.7, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 14, y: 12, width: 28, height: 28))
        // 발광 코어
        ctx.setFillColor(red: color.0, green: color.1, blue: color.2, alpha: 0.6 + 0.4 * glow)
        ctx.fillEllipse(in: CGRect(x: cx - 8, y: 18, width: 16, height: 16))
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        ctx.fillEllipse(in: CGRect(x: cx - 4, y: 22, width: 8, height: 8))
    }
}

// MARK: - 📡 스컬크 센서: 클릭 진동 감지 + 딩동 + 감도 3단계

public final class GSculkSensorWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (Int) -> Void
    private var tick: Timer?
    private var phase: TimeInterval = 0
    private var vibeLeft: TimeInterval = 0
    private var drawView: GSculkSensorDrawView?
    private let panelW: CGFloat = 64
    private let panelH: CGFloat = 56
    var sensitivity = 2

    public init(startPos: CGPoint, onTap: @escaping (Int) -> Void) {
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
        let view = GSculkSensorDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        tick = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            self.phase += 1.0 / 60.0
            if self.vibeLeft > 0 { self.vibeLeft -= 1.0 / 60.0 }
            self.drawView?.vibe = max(0, self.vibeLeft)
            self.drawView?.sensitivity = self.sensitivity
            self.drawView?.needsDisplay = true
        }
        RunLoop.main.add(tick!, forMode: .common)
    }

    public override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            sensitivity = sensitivity % 3 + 1
            RewardCenter.say("📡 감도 \(sensitivity)/3")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        vibeLeft = 0.4 + Double(sensitivity) * 0.2
        onTap(sensitivity)
    }

    public override func close() {
        tick?.invalidate()
        tick = nil
        super.close()
    }
}

private final class GSculkSensorDrawView: NSView {
    var vibe: TimeInterval = 0
    var sensitivity = 2

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let cx = bounds.width / 2
        // 진동 파문
        if vibe > 0 {
            let r = CGFloat(1.0 - vibe) * 40.0 + 14
            ctx.setStrokeColor(red: 0.35, green: 0.90, blue: 1.0, alpha: CGFloat(vibe) * 1.2)
            ctx.setLineWidth(2.0)
            ctx.strokeEllipse(in: CGRect(x: cx - r / 2, y: 24 - r / 2, width: r, height: r))
        }
        // 본체 (스컬크 청록)
        ctx.setFillColor(red: 0.10, green: 0.25, blue: 0.30, alpha: 1.0)
        ctx.fill(CGRect(x: cx - 16, y: 8, width: 32, height: 22))
        // 촉수 결
        ctx.setStrokeColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1.0)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: cx - 12, y: 14))
        ctx.addLine(to: CGPoint(x: cx + 12, y: 20))
        ctx.move(to: CGPoint(x: cx - 12, y: 24))
        ctx.addLine(to: CGPoint(x: cx + 12, y: 14))
        ctx.strokePath()
        // 감도 표시등 (최대 3개)
        for i in 0..<3 {
            if i < sensitivity {
                ctx.setFillColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.20, green: 0.35, blue: 0.40, alpha: 1.0)
            }
            ctx.fillEllipse(in: CGRect(x: cx - 12 + CGFloat(i) * 10, y: 2, width: 6, height: 6))
        }
    }
}

// MARK: - 🛏️ 침대: 16색 순환 + 수면 연출

public final class GBedWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (String) -> Void
    private var drawView: GBedDrawView?
    private let panelW: CGFloat = 96
    private let panelH: CGFloat = 56

    static let dyes: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("빨강", 0.75, 0.15, 0.15), ("주황", 0.90, 0.45, 0.10),
        ("노랑", 0.95, 0.85, 0.20), ("라임", 0.55, 0.85, 0.20),
        ("초록", 0.20, 0.60, 0.25), ("청록", 0.15, 0.65, 0.60),
        ("하늘", 0.35, 0.70, 0.95), ("파랑", 0.20, 0.35, 0.85),
        ("남색", 0.25, 0.25, 0.55), ("보라", 0.50, 0.25, 0.70),
        ("자홍", 0.80, 0.25, 0.60), ("분홍", 0.95, 0.60, 0.70),
        ("갈색", 0.45, 0.30, 0.18), ("회색", 0.50, 0.50, 0.52),
        ("밝은회색", 0.75, 0.75, 0.78), ("흰색", 0.93, 0.93, 0.94),
    ]
    var dyeIndex = 13

    public init(startPos: CGPoint, onTap: @escaping (String) -> Void) {
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
        let view = GBedDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        syncDraw()
    }

    private func syncDraw() {
        let d = GBedWindow.dyes[dyeIndex]
        drawView?.blanket = (d.1, d.2, d.3)
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        dyeIndex = (dyeIndex + 1) % GBedWindow.dyes.count
        syncDraw()
        drawView?.sleeping = true
        drawView?.needsDisplay = true
        onTap(GBedWindow.dyes[dyeIndex].0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.drawView?.sleeping = false
            self?.drawView?.needsDisplay = true
        }
    }
}

private final class GBedDrawView: NSView {
    var blanket: (CGFloat, CGFloat, CGFloat) = (0.75, 0.15, 0.15)
    var sleeping = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 다리
        ctx.setFillColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 2, width: 6, height: 10))
        ctx.fill(CGRect(x: 82, y: 2, width: 6, height: 10))
        // 프레임
        ctx.fill(CGRect(x: 6, y: 10, width: 84, height: 8))
        // 베개
        ctx.setFillColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0)
        ctx.fill(CGRect(x: 8, y: 18, width: 18, height: 14))
        // 이불 (염색색)
        ctx.setFillColor(red: blanket.0, green: blanket.1, blue: blanket.2, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 18, width: 62, height: 14))
        // 이불 주름
        ctx.setFillColor(red: blanket.0 * 0.8, green: blanket.1 * 0.8, blue: blanket.2 * 0.8, alpha: 1.0)
        ctx.fill(CGRect(x: 26, y: 18, width: 62, height: 3))
        // 수면 표시
        if sleeping {
            let s = "💤" as NSString
            s.draw(at: CGPoint(x: 70, y: 34), withAttributes: [.font: NSFont.systemFont(ofSize: 16)])
        }
    }
}

// MARK: - 🖼️ 지도 벽: 9칸 중 클릭당 1칸씩 채우기

public final class GMapWallWindow: NSPanel {
    public var position: CGPoint
    private let onTap: (Int) -> Void
    private var drawView: GMapWallDrawView?
    private let panelW: CGFloat = 120
    private let panelH: CGFloat = 120
    var filled = 0

    public init(startPos: CGPoint, onTap: @escaping (Int) -> Void) {
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
        let view = GMapWallDrawView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        self.drawView = view
        contentView = view
    }

    public func start() {
        orderFrontRegardless()
        SoundAndEffectsManager.shared.play(.pop)
        drawView?.filled = filled
        drawView?.needsDisplay = true
    }

    public override func mouseDown(with event: NSEvent) {
        if filled >= 9 {
            filled = 0
            drawView?.filled = filled
            drawView?.needsDisplay = true
            RewardCenter.say("🖼️ 새 탐험을 시작하자!")
            SoundAndEffectsManager.shared.play(.pop)
            return
        }
        filled += 1
        drawView?.filled = filled
        drawView?.needsDisplay = true
        onTap(filled)
    }
}

private final class GMapWallDrawView: NSView {
    var filled = 0

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // 액자 틀
        ctx.setFillColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1.0)
        ctx.fill(CGRect(x: 4, y: 4, width: 112, height: 112))
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.45, 0.70, 0.35), (0.35, 0.55, 0.80), (0.85, 0.80, 0.60),
            (0.55, 0.45, 0.32), (0.30, 0.60, 0.30),
        ]
        for i in 0..<9 {
            let col = i % 3
            let row = i / 3
            let x = 10.0 + CGFloat(col) * 34.0
            let y = 78.0 - CGFloat(row) * 34.0
            if i < filled {
                let c = palette[(i * 7 + 3) % palette.count]
                ctx.setFillColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
            } else {
                ctx.setFillColor(red: 0.72, green: 0.66, blue: 0.55, alpha: 1.0)
            }
            ctx.fill(CGRect(x: x, y: y, width: 30, height: 30))
            if i < filled {
                // 탐험 마크
                ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7)
                ctx.fillEllipse(in: CGRect(x: x + 12, y: y + 12, width: 6, height: 6))
            } else {
                // 미개척 테두리
                ctx.setStrokeColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 1.0)
                ctx.setLineWidth(1.0)
                ctx.stroke(CGRect(x: x + 4, y: y + 4, width: 22, height: 22))
            }
        }
    }
}
