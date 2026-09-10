import Foundation

public enum PetKind: String, CaseIterable {
    case wolf = "wolf"
    case cat = "cat"
    case parrot = "parrot"
    case pig = "pig"
    case horse = "horse"

    public var displayName: String {
        switch self {
        case .wolf: return "🐺 길들인 늑대 (Wolf)"
        case .cat: return "🐱 턱시도 고양이 (Cat)"
        case .parrot: return "🦜 붉은 앵무새 (Parrot)"
        case .pig: return "🐷 아기 돼지 (Pig)"
        case .horse: return "🐴 길들인 말 (Horse)"
        }
    }

    public var clickEmoji: String {
        switch self {
        case .wolf: return "🦴"
        case .cat: return "🐟"
        case .parrot: return "🌾"
        case .pig: return "🥕"
        case .horse: return "🍎"
        }
    }

    public var sitEmoji: String {
        switch self {
        case .wolf: return "🐾"
        case .cat: return "💤"
        case .parrot: return "🦜"
        case .pig: return "🐷"
        case .horse: return "🐴"
        }
    }

    public var heartEmoji: String {
        return "❤️"
    }
}
