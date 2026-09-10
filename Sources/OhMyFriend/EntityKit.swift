import CoreGraphics
import Foundation

// Entity 공통 프레임워크: 배치 19파일에 흩어진 배회·타격·쿨다운·토글 상용구를
// 순수 값 타입 + 제네릭 슬롯으로 응축. 새 몹 추가는 선언만으로 끝나야 한다.

// 배회: 방향 전환 주기 + 속도를 가진 순수 상태. 타이머 소유는 창이 한다.
public struct WanderState {
    public var direction: CGFloat
    public var speed: CGFloat
    private var flipTimer: TimeInterval

    public init(speed: CGFloat, direction: CGFloat = 1) {
        self.speed = speed
        self.direction = direction
        self.flipTimer = Double.random(in: 2.5...5.0)
    }

    public mutating func tick(_ dt: TimeInterval) -> CGFloat {
        flipTimer -= dt
        if flipTimer <= 0 {
            flipTimer = Double.random(in: 2.5...5.0)
            direction = Bool.random() ? 1 : -1
        }
        return direction * speed * CGFloat(dt)
    }
}

// 타격: N타 격퇴 카운터. true를 반환하면 격퇴된 것이다.
public struct HitCounter {
    public let maxHits: Int
    public private(set) var hits: Int = 0

    public init(maxHits: Int) { self.maxHits = maxHits }

    public mutating func hit() -> Bool {
        hits += 1
        return hits >= maxHits
    }

    public mutating func reset() { hits = 0 }
}

// 쿨다운: 메뉴 중복 실행·연타 방지 게이트.
public struct Cooldown {
    public private(set) var remaining: TimeInterval = 0

    public init() {}

    public var ready: Bool { remaining <= 0 }

    public mutating func tick(_ dt: TimeInterval) {
        if remaining > 0 { remaining -= dt }
    }

    public mutating func trigger(_ duration: TimeInterval) { remaining = duration }
}

// 토글 슬롯: 스폰/해제 쌍을 한 줄로. 창 수명주기는 슬롯이 소유한다.
public final class ToggleSlot<W: EntityWindow> {
    private var window: W?

    public init() {}

    public var isActive: Bool { window != nil }

    public func toggle(make: () -> W, start: (W) -> Void) {
        if let w = window {
            w.close()
            window = nil
        } else {
            let w = make()
            window = w
            start(w)
        }
    }

    public func clear() {
        window?.close()
        window = nil
    }
}
