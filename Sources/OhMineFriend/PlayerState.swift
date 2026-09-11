import Foundation

/// 플레이어 상태(재화·카운터·버프 타이머·강화 수치) 보관소.
/// AppController의 private/public 상태 필드를 동작 변경 없이 이관한 클래스.
/// 필드명·초기값은 기존 AppController 선언과 100% 동일하게 유지한다.
public final class PlayerState {
    // 공격 쿨다운
    public var playerAttackTimer: TimeInterval = 0
    // 재화·카운터
    public var playerXP: Int = 0
    public var playerEmeralds: Int = 0
    public var playerWheat: Int = 0
    public var playerHorns: Int = 0
    // 강화 수치
    public var swordSharpness: Int = 0
    public var pickaxeEfficiency: Int = 0
    // 버프·디버프 타이머
    public var swiftTimer: TimeInterval = 0
    public var invisTimer: TimeInterval = 0
    public var strengthTimer: TimeInterval = 0
    public var witchSlowTimer: TimeInterval = 0
    public var milkCleanseTimer: TimeInterval = 0
    // 버프 플래그
    public var hasGlisteringMelon: Bool = false
}
