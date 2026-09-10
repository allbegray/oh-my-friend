import Foundation

/// 마인크래프트 원작 낚시 전리품 테이블
public struct FishingLoot {
    public static func roll() -> (name: String, emoji: String) {
        let roll = Int.random(in: 1...100)
        if roll <= 45 {
            return ("날생선 낚음!", "🐟")
        } else if roll <= 70 {
            return ("연어 낚음!", "🍣")
        } else if roll <= 85 {
            return ("복어 낚음! 찌릿!", "🐡")
        } else if roll <= 93 {
            return ("낡은 가죽 장화... 쩝", "👞")
        } else if roll <= 97 {
            return ("마법이 부여된 책!", "📖")
        } else {
            return ("초대박! 네더라이트 주괴!", "💎")
        }
    }
}
