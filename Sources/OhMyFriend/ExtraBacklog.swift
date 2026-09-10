import AppKit
import CoreGraphics

// 9~17차 백로그 공용 허브: 메뉴 기술자 + 보상/위치 브리지 + 클로저 메뉴 아이템.
// 배치 매니저(Extra9~Extra17)는 이 파일의 API만 사용해 AppController와 연동한다.

public struct ExtraMenuEntry {
    public let title: () -> String
    public let run: () -> Void
    public init(_ title: @escaping () -> String, _ run: @escaping () -> Void) {
        self.title = title
        self.run = run
    }
}

public final class RewardCenter {
    public static var onReward: ((Int, String) -> Void)?
    public static var playerPos: (() -> CGPoint)?
    public static var movePlayer: ((CGPoint) -> Void)?
    public static var friendPos: (() -> CGPoint?)?
    public static var heldItemName: (() -> String)?

    public static func grant(xp: Int, _ emoji: String) { onReward?(xp, emoji) }
    public static func say(_ emoji: String) { onReward?(0, emoji) }
    public static func me() -> CGPoint { playerPos?() ?? .zero }
}

public final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void
    public init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        self.target = self
    }
    public required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func fire() { run() }
}
