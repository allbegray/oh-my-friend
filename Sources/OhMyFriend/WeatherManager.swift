import Foundation

public enum WeatherState {
    case clear
    case rain
    case thunderstorm
}

public final class WeatherManager {
    public static let shared = WeatherManager()
    public var isEnabled: Bool = true
    public private(set) var state: WeatherState = .clear

    private var stateTimer: TimeInterval = 0
    private var nextChange: TimeInterval = 25.0
    public private(set) var thunderStrikeTimer: TimeInterval = 4.0
    public var shouldStrike: Bool = false

    private init() {}

    public func update(dt: TimeInterval) {
        guard isEnabled else { return }
        stateTimer += dt
        if stateTimer >= nextChange {
            stateTimer = 0
            nextChange = Double.random(in: 20.0...30.0)
            let roll = Double.random(in: 0...1)
            switch state {
            case .clear:
                state = roll < 0.55 ? .clear : (roll < 0.85 ? .rain : .thunderstorm)
            case .rain:
                state = roll < 0.5 ? .clear : (roll < 0.8 ? .rain : .thunderstorm)
            case .thunderstorm:
                state = roll < 0.6 ? .rain : .clear
            }
            if state == .thunderstorm {
                thunderStrikeTimer = 2.0
            }
        }
        if state == .thunderstorm {
            thunderStrikeTimer -= dt
            if thunderStrikeTimer <= 0 {
                thunderStrikeTimer = Double.random(in: 3.0...5.0)
                shouldStrike = true
            }
        }
    }

    public func consumeStrike() -> Bool {
        guard shouldStrike else { return false }
        shouldStrike = false
        return true
    }

    public var isRaining: Bool {
        state == .rain || state == .thunderstorm
    }

    public var isThunder: Bool {
        state == .thunderstorm
    }
}
