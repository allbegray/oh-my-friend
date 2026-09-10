import AppKit
import CoreGraphics
import Foundation

public enum SkeletonState {
    case roaming(direction: CGFloat, timer: TimeInterval)
    case aiming(playerPos: CGPoint, chargeTimer: TimeInterval)
    case fleeingSun(targetShadeX: CGFloat, timer: TimeInterval)
    case hurt(knockbackVx: CGFloat, timer: TimeInterval)
    case dying(timer: TimeInterval)
}

public final class SkeletonBehaviorController {
    public private(set) var state: SkeletonState = .roaming(direction: 1.0, timer: 3.0)
    public private(set) var hp: Int = 3
    public var isDespawned: Bool = false

    private let walkSpeed: CGFloat = 50.0
    private let fleeSpeed: CGFloat = 85.0
    private let aimDistance: CGFloat = 340.0
    private var aimCooldown: TimeInterval = 4.0

    public init() {}

    public func update(
        deltaTime dt: CGFloat,
        skeletonPhysics: PhysicsEngine,
        skeletonNode: SkeletonNode,
        playerPos: CGPoint,
        platforms: [Platform],
        screen: NSScreen,
        onShootArrow: @escaping (CGPoint, CGPoint) -> Void,
        onDefeated: @escaping () -> Void
    ) {
        guard !isDespawned else { return }

        let skelPos = skeletonPhysics.position
        let dxToPlayer = playerPos.x - skelPos.x
        let distToPlayer = hypot(dxToPlayer, playerPos.y - skelPos.y)
        let dirToPlayer: CGFloat = dxToPlayer >= 0 ? 1.0 : -1.0

        // 1. 원작 고증: 낮(06:00~18:00) 시간대 햇빛 발화 검사
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isDaytime = currentHour >= 6 && currentHour < 18

        // 창문 그늘 아래에 있는지 검사 (스켈레톤 머리 위로 창문이 덮고 있는지)
        let isUnderShade = platforms.contains { p in
            guard case .window = p.kind, let bottom = p.yBottom else { return false }
            return bottom > skelPos.y && skelPos.x >= (p.xMin - 20) && skelPos.x <= (p.xMax + 20)
        }

        let shouldBurnInSun = isDaytime && !isUnderShade
        skeletonNode.isBurning = shouldBurnInSun

        // 햇빛에 불타는 경우 그늘로 피신 우선!
        if shouldBurnInSun {
            if case .fleeingSun = state {} else if case .dying = state {} else {
                skeletonNode.showOverheadEmoji("🔥 치이익! 햇빛이다!", duration: 1.5)
                SoundAndEffectsManager.shared.play(.ignite)
                // 가장 가까운 창문 그늘 X좌표 탐색
                let nearestShade = platforms.first { p in
                    guard case .window = p.kind else { return false }
                    return p.yBottom != nil
                }
                let targetX = nearestShade?.xMin ?? (screen.frame.minX + 80)
                state = .fleeingSun(targetShadeX: targetX, timer: 4.0)
            }
        }

        switch state {
        case .roaming(var dir, var timer):
            timer -= Double(dt)
            aimCooldown -= Double(dt)
            skeletonNode.isAiming = false
            skeletonNode.walkSpeed = walkSpeed
            skeletonNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            skeletonPhysics.position.x += dir * walkSpeed * dt

            // 화면 가장자리 반전
            if skeletonPhysics.position.x <= screen.frame.minX + 40 && dir < 0 {
                dir = 1.0
            } else if skeletonPhysics.position.x >= screen.frame.maxX - 40 && dir > 0 {
                dir = -1.0
            }

            // 플레이어가 조준 사정거리(340pt) 이내에 있고 쿨다운 완료 시 조준 돌입!
            if distToPlayer < aimDistance && aimCooldown <= 0 {
                aimCooldown = 4.5
                skeletonNode.walkSpeed = 0
                skeletonNode.isAiming = true
                skeletonNode.showOverheadEmoji("🎯 조준 중...", duration: 1.8)
                state = .aiming(playerPos: playerPos, chargeTimer: 0)
                return
            }

            if timer <= 0 {
                timer = Double.random(in: 2.0...4.5)
                dir = Bool.random() ? 1.0 : -1.0
            }
            state = .roaming(direction: dir, timer: timer)

        case .aiming(let targetPos, var chargeTimer):
            chargeTimer += Double(dt)
            skeletonNode.walkSpeed = 0
            skeletonNode.isAiming = true

            // 플레이어 방향을 조준
            skeletonNode.modelRoot.eulerAngles.y = dirToPlayer > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            if chargeTimer >= 1.8 {
                // 발사! (Arrow shoot!)
                skeletonNode.isAiming = false
                skeletonNode.showOverheadEmoji("🏹 핑!", duration: 1.2)
                SoundAndEffectsManager.shared.play(.pop)

                let arrowStart = CGPoint(x: skelPos.x, y: skelPos.y + 35)
                onShootArrow(arrowStart, targetPos)

                state = .roaming(direction: -dirToPlayer, timer: 2.5)
            } else {
                state = .aiming(playerPos: playerPos, chargeTimer: chargeTimer)
            }

        case .fleeingSun(let targetX, var timer):
            timer -= Double(dt)
            skeletonNode.isAiming = false
            skeletonNode.walkSpeed = fleeSpeed

            let dir: CGFloat = targetX >= skelPos.x ? 1.0 : -1.0
            skeletonNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            skeletonPhysics.position.x += dir * fleeSpeed * dt

            // 그늘에 안착했거나 타이머 만료 시
            if isUnderShade || timer <= 0 {
                state = .roaming(direction: dir, timer: 3.0)
            } else {
                state = .fleeingSun(targetShadeX: targetX, timer: timer)
            }

        case .hurt(let kbVx, var timer):
            timer -= Double(dt)
            skeletonPhysics.position.x += kbVx * dt
            skeletonNode.walkSpeed = 0

            if timer <= 0 {
                state = .roaming(direction: -dirToPlayer, timer: 2.0)
            } else {
                state = .hurt(knockbackVx: kbVx * 0.88, timer: timer)
            }

        case .dying(var timer):
            timer -= Double(dt)
            skeletonNode.isDying = true
            skeletonNode.walkSpeed = 0

            if timer <= 0 {
                isDespawned = true
                onDefeated()
            } else {
                state = .dying(timer: timer)
            }
        }
    }

    public func applyDamage(
        _ damage: Int,
        fromPlayerAt playerPos: CGPoint,
        weapon: HeldItem,
        skeletonPhysics: PhysicsEngine,
        skeletonNode: SkeletonNode,
        onDefeated: @escaping () -> Void
    ) {
        guard !isDespawned else { return }

        hp -= damage
        let dx = skeletonPhysics.position.x - playerPos.x
        let knockbackDir: CGFloat = dx >= 0 ? 1.0 : -1.0

        if hp <= 0 {
            let loots = ["🦴 뼈다귀 획득!", "➡️ 화살 획득!", "🏹 낡은 활 획득!"]
            skeletonNode.showOverheadEmoji(loots.randomElement() ?? loots[0], duration: 2.2)
            SoundAndEffectsManager.shared.play(.pop)
            state = .dying(timer: 0.85)
        } else {
            SoundAndEffectsManager.shared.play(.pop)
            skeletonNode.showOverheadEmoji("💢 -1", duration: 1.0)
            let kbPower: CGFloat = weapon == .diamondSword ? 260.0 : 180.0
            state = .hurt(knockbackVx: knockbackDir * kbPower, timer: 0.25)
        }
    }
}
