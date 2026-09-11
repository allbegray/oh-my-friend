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

    /// 스켈레톤이 생존해 있는지 여부 (쓰러지거나 사망 진행 중일 때는 false)
    public var isAlive: Bool {
        if isDespawned || hp <= 0 { return false }
        switch state {
        case .dying:
            return false
        default:
            return true
        }
    }

    private let walkSpeed: CGFloat = 50.0
    private let fleeSpeed: CGFloat = 85.0
    private let aimDistance: CGFloat = 340.0
    private var aimCooldown: TimeInterval = 4.0
    private var sunPanicCooldown: TimeInterval = 0
    private var turnCooldown: TimeInterval = 0

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

        if sunPanicCooldown > 0 {
            sunPanicCooldown -= Double(dt)
        }
        if turnCooldown > 0 {
            turnCooldown -= Double(dt)
        }

        let skelPos = skeletonPhysics.position
        let dxToPlayer = playerPos.x - skelPos.x
        let distToPlayer = hypot(dxToPlayer, playerPos.y - skelPos.y)
        let dirToPlayer: CGFloat = dxToPlayer >= 0 ? 1.0 : -1.0

        // 1. 원작 고증: 낮(06:00~18:00) 시간대 햇빛 발화 검사
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isDaytime = currentHour >= 6 && currentHour < 18

        // 창문 그늘 아래에 있는지 검사 (스켈레톤 머리 위로 창문이 덮고 있는지)
        let currentShade = platforms.first { p in
            guard case .window = p.kind, let bottom = p.yBottom else { return false }
            return bottom > skelPos.y && skelPos.x >= (p.xMin - 15) && skelPos.x <= (p.xMax + 15)
        }
        let isUnderShade = currentShade != nil

        let shouldBurnInSun = isDaytime && !isUnderShade
        skeletonNode.isBurning = shouldBurnInSun

        // 햇빛에 불타는 경우 그늘로 피신 (단, 그늘이 없을 때는 벽에 계속 비비지 않도록 쿨다운 적용)
        if shouldBurnInSun && sunPanicCooldown <= 0 {
            if case .fleeingSun = state {} else if case .dying = state {} else {
                // 머리 위로 덮어주는 실제 창문 그늘 탐색
                let nearestShade = platforms.first { p in
                    guard case .window = p.kind, let bottom = p.yBottom else { return false }
                    return bottom > skelPos.y
                }
                if let shade = nearestShade {
                    skeletonNode.showOverheadEmoji("🔥 치이익! 그늘로!", duration: 1.5)
                    SoundAndEffectsManager.shared.play(.ignite)
                    let targetX = (shade.xMin + shade.xMax) / 2.0
                    turnCooldown = 1.5
                    state = .fleeingSun(targetShadeX: targetX, timer: 6.0)
                } else {
                    // 창문 그늘이 전혀 없으면 화면 중앙 방향으로 패닉 질주
                    skeletonNode.showOverheadEmoji("🔥 으악! 그늘이 없어!", duration: 1.5)
                    SoundAndEffectsManager.shared.play(.ignite)
                    sunPanicCooldown = 8.0
                    turnCooldown = 2.0
                    let fleeDir: CGFloat = skeletonPhysics.position.x > screen.frame.midX ? -1.0 : 1.0
                    state = .roaming(direction: fleeDir, timer: 3.5)
                }
            }
        }

        let leftEdge = screen.frame.minX + 45.0
        let rightEdge = screen.frame.maxX - 45.0

        switch state {
        case .roaming(var dir, var timer):
            timer -= Double(dt)
            aimCooldown -= Double(dt)
            skeletonNode.isAiming = false
            skeletonNode.walkSpeed = walkSpeed

            // 낮 시간대 그늘 안에 있으면 그늘 밖으로 뛰어나가지 않고 그늘 내부를 순찰
            if isDaytime, let shade = currentShade {
                sunPanicCooldown = 4.0
                let shadeMinX = shade.xMin + 20.0
                let shadeMaxX = shade.xMax - 20.0
                if shadeMaxX > shadeMinX {
                    if skeletonPhysics.position.x <= shadeMinX && dir < 0 {
                        dir = 1.0
                        turnCooldown = 1.5
                        timer = Double.random(in: 2.5...4.5)
                    } else if skeletonPhysics.position.x >= shadeMaxX && dir > 0 {
                        dir = -1.0
                        turnCooldown = 1.5
                        timer = Double.random(in: 2.5...4.5)
                    }
                }
            }

            // 화면 가장자리 반전 및 벽 충돌 방어
            if skeletonPhysics.position.x <= leftEdge {
                skeletonPhysics.position.x = leftEdge
                dir = 1.0
                turnCooldown = 1.5
                if timer < 2.0 { timer = Double.random(in: 2.5...4.5) }
            } else if skeletonPhysics.position.x >= rightEdge {
                skeletonPhysics.position.x = rightEdge
                dir = -1.0
                turnCooldown = 1.5
                if timer < 2.0 { timer = Double.random(in: 2.5...4.5) }
            }

            skeletonNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            skeletonPhysics.position.x += dir * walkSpeed * dt

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
                timer = Double.random(in: 2.5...5.0)
                if turnCooldown <= 0 {
                    if skeletonPhysics.position.x <= screen.frame.minX + 90.0 {
                        dir = 1.0
                        turnCooldown = 1.5
                    } else if skeletonPhysics.position.x >= screen.frame.maxX - 90.0 {
                        dir = -1.0
                        turnCooldown = 1.5
                    } else {
                        let newDir = Bool.random() ? 1.0 : -1.0
                        if newDir != dir {
                            dir = newDir
                            turnCooldown = 1.5
                        }
                    }
                }
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

                turnCooldown = 2.0
                state = .roaming(direction: -dirToPlayer, timer: 2.8)
            } else {
                state = .aiming(playerPos: playerPos, chargeTimer: chargeTimer)
            }

        case .fleeingSun(let targetX, var timer):
            timer -= Double(dt)
            skeletonNode.isAiming = false
            skeletonNode.walkSpeed = fleeSpeed

            var dir: CGFloat = targetX >= skelPos.x ? 1.0 : -1.0

            // 벽 충돌 가드: 화면 끝에 닿으면 즉시 튕겨서 반대편으로 방향 전환
            var hitWall = false
            if skeletonPhysics.position.x <= leftEdge {
                skeletonPhysics.position.x = leftEdge
                dir = 1.0
                hitWall = true
            } else if skeletonPhysics.position.x >= rightEdge {
                skeletonPhysics.position.x = rightEdge
                dir = -1.0
                hitWall = true
            }

            skeletonNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            skeletonPhysics.position.x += dir * fleeSpeed * dt

            // 그늘에 안착했거나 타깃에 도달 시: 억지로 반대방향(-dir)으로 돌려 햇빛으로 나가지 않고 그늘 안에서 안정적으로 배회
            let reachedTarget = abs(skelPos.x - targetX) < 35.0
            if isUnderShade || reachedTarget {
                sunPanicCooldown = 4.0
                turnCooldown = 1.5
                state = .roaming(direction: dir, timer: Double.random(in: 3.0...5.0))
            } else if hitWall || timer <= 0 {
                sunPanicCooldown = 4.0
                turnCooldown = 1.5
                state = .roaming(direction: -dir, timer: Double.random(in: 2.5...4.0))
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
        guard isAlive else { return }

        hp -= damage
        let dx = skeletonPhysics.position.x - playerPos.x
        let knockbackDir: CGFloat = dx >= 0 ? 1.0 : -1.0

        if hp <= 0 {
            hp = 0
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
