import Foundation

public enum DayNightMode: String, CaseIterable {
    case automatic = "자동 (시간 연동)"
    case forceDay = "항상 낮 ☀️"
    case forceNight = "항상 밤 🌙"
}

public final class DayNightCycleManager {
    public static let shared = DayNightCycleManager()
    public var mode: DayNightMode = .automatic
    public private(set) var isNight: Bool = false
    public var morningSkipUntil: Date?

    private init() {
        refresh()
    }

    public func refresh() {
        switch mode {
        case .forceDay:
            isNight = false
            return
        case .forceNight:
            isNight = true
            return
        case .automatic:
            break
        }
        if let until = morningSkipUntil, Date() < until {
            isNight = false
            return
        }
        morningSkipUntil = nil
        let hour = Calendar.current.component(.hour, from: Date())
        isNight = (hour >= 18 || hour < 6)
    }

    public func skipToMorning(minutes: Double = 15.0) {
        morningSkipUntil = Date().addingTimeInterval(minutes * 60.0)
        refresh()
    }

    public var nightSpawnMultiplier: Double {
        isNight ? 1.5 : 1.0
    }
}
