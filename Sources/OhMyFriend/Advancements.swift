import AppKit
import CoreGraphics

public enum AdvancementID: String, CaseIterable {
    case firstMine
    case creeperKill
    case skeletonKill
    case endermanKill
    case slimeKill
    case wolfTame
    case horseTame
    case firstHarvest
    case fishingLoot
    case brewing
    case enchanting
    case trading
    case portalTrip
    case horseRide
    case buddySummon
    case nightSkip

    public var title: String {
        switch self {
        case .firstMine: return "⛏️ 첫 채굴"
        case .creeperKill: return "💥 크리퍼 사냥꾼"
        case .skeletonKill: return "🏹 스켈레톤 저격수"
        case .endermanKill: return "👁️ 엔더맨 정복자"
        case .slimeKill: return "🟢 슬라임 분해자"
        case .wolfTame: return "🐺 늑대 조련사"
        case .horseTame: return "🐴 기수"
        case .firstHarvest: return "🌾 첫 수확"
        case .fishingLoot: return "🎣 강태공"
        case .brewing: return "🧪 견습 양조사"
        case .enchanting: return "📖 마법 부여사"
        case .trading: return "🧑‍🌾 흥정왕"
        case .portalTrip: return "🟣 차원 여행자"
        case .horseRide: return "🐎 질주 본능"
        case .buddySummon: return "👥 친구야 모여라"
        case .nightSkip: return "☀️ 굿모닝"
        }
    }

    public var desc: String {
        switch self {
        case .firstMine: return "블록을 설치하고 캐기"
        case .creeperKill: return "크리퍼 처치하기"
        case .skeletonKill: return "스켈레톤 처치하기"
        case .endermanKill: return "엔더맨 처치하기"
        case .slimeKill: return "슬라임 처치하기"
        case .wolfTame: return "야생 늑대 길들이기"
        case .horseTame: return "야생마 길들이기"
        case .firstHarvest: return "밀 수확하기"
        case .fishingLoot: return "낚시로 전리품 낚기"
        case .brewing: return "물약 양조하기"
        case .enchanting: return "무기 인챈트하기"
        case .trading: return "주민과 거래하기"
        case .portalTrip: return "지옥문 통과하기"
        case .horseRide: return "말 타고 질주하기"
        case .buddySummon: return "친구 소환하기"
        case .nightSkip: return "밤샘 수면으로 아침 스킵"
        }
    }
}

public final class AdvancementManager {
    public static let shared = AdvancementManager()
    private let defaults = UserDefaults.standard
    private var toastQueue: [AdvancementID] = []
    private var toastWindow: AdvancementToastWindow?
    public var onUnlock: (() -> Void)?

    private init() {}

    public func isUnlocked(_ id: AdvancementID) -> Bool {
        defaults.bool(forKey: "adv_\(id.rawValue)")
    }

    public var unlockedCount: Int {
        AdvancementID.allCases.filter { isUnlocked($0) }.count
    }

    @discardableResult
    public func unlock(_ id: AdvancementID) -> Bool {
        guard !isUnlocked(id) else { return false }
        defaults.set(true, forKey: "adv_\(id.rawValue)")
        toastQueue.append(id)
        showNextToast()
        onUnlock?()
        return true
    }

    private func showNextToast() {
        guard toastWindow == nil, let next = toastQueue.first else { return }
        toastQueue.removeFirst()
        let toast = AdvancementToastWindow(advancement: next) { [weak self] in
            self?.toastWindow = nil
            self?.showNextToast()
        }
        toastWindow = toast
        toast.show()
        SoundAndEffectsManager.shared.play(.chime)
    }
}

private final class AdvancementToastWindow: NSPanel {
    private let onDone: () -> Void
    private var timer: Timer?

    init(advancement: AdvancementID, onDone: @escaping () -> Void) {
        self.onDone = onDone
        let size = NSSize(width: 280, height: 64)
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(
            x: screen.maxX - size.width - 16,
            y: screen.maxY - size.height - 40,
            width: size.width,
            height: size.height
        )
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = AdvancementToastDrawView(
            frame: NSRect(origin: .zero, size: size),
            title: "🏆 발전 과제 달성!",
            subtitle: advancement.title
        )
        contentView = view
    }

    func show() {
        orderFrontRegardless()
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0
        }
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                self.animator().alphaValue = 0
            }, completionHandler: {
                self.close()
                self.onDone()
            })
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}

private final class AdvancementToastDrawView: NSView {
    private let title: String
    private let subtitle: String

    init(frame: NSRect, title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.92)
        let path = CGPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setFillColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0)
        ctx.fill(CGRect(x: 2, y: 2, width: bounds.width - 4, height: 3))
        let titleAttr = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.systemYellow]
        )
        titleAttr.draw(at: NSPoint(x: 14, y: 32))
        let subAttr = NSAttributedString(
            string: subtitle,
            attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.white]
        )
        subAttr.draw(at: NSPoint(x: 14, y: 10))
    }
}

public final class AdvancementListWindow: NSPanel {
    public init() {
        let size = NSSize(width: 340, height: 420)
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        super.init(
            contentRect: NSRect(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.title = "🏆 발전 과제"
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: size))
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: size.width - 16, height: 800))
        text.isEditable = false
        text.font = NSFont.systemFont(ofSize: 13)
        let full = NSMutableAttributedString()
        for id in AdvancementID.allCases {
            let mark = AdvancementManager.shared.isUnlocked(id) ? "✅" : "⬜"
            full.append(NSAttributedString(string: "\(mark) \(id.title)\n    \(id.desc)\n"))
        }
        full.append(NSAttributedString(
            string: "\n달성: \(AdvancementManager.shared.unlockedCount)/\(AdvancementID.allCases.count)"
        ))
        text.textStorage?.setAttributedString(full)
        text.sizeToFit()
        scroll.documentView = text
        contentView = scroll
    }
}
