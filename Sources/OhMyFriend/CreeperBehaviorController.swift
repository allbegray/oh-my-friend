import AppKit
import CoreGraphics
import Foundation

public enum CreeperState {
    case stalking
    case hissing(fuseElapsed: TimeInterval)
    case burningPanic(timeLeft: TimeInterval)
    case fleeingFromCat(timeLeft: TimeInterval)
    case hurt(knockbackVx: CGFloat, timer: TimeInterval)
    case dying(timer: TimeInterval)
    case exploded
}

public final class CreeperBehaviorController {
    public private(set) var state: CreeperState = .stalking
    public private(set) var hp: Int = 3
    public var isDespawned: Bool = false

    private let stalkSpeed: CGFloat = 55.0
    private let fuseDuration: TimeInterval = 2.8 // 2.8s fuse before boom
    private let attackProximity: CGFloat = 120.0
    private let escapeProximity: CGFloat = 175.0

    public init() {}

    public func update(
        deltaTime dt: CGFloat,
        creeperPhysics: PhysicsEngine,
        creeperNode: CreeperNode,
        playerPos: CGPoint,
        catPos: CGPoint? = nil,
        onExplode: @escaping (CGPoint) -> Void,
        onDefeated: @escaping () -> Void
    ) {
        guard !isDespawned else { return }

        let creeperPos = creeperPhysics.position
        let dx = playerPos.x - creeperPos.x
        let dy = playerPos.y - creeperPos.y
        let dist = hypot(dx, dy)
        let dirToPlayer: CGFloat = dx > 0 ? 1.0 : -1.0


        // 원작 고증: 크리퍼는 고양이를 극도로 무서워하여 근처에 오면 도화선을 즉시 끄고 도망침!
        if let cat = catPos {
            let catDist = hypot(cat.x - creeperPos.x, cat.y - creeperPos.y)
            if catDist < 220.0 {
                switch state {
                case .stalking, .hissing:
                    creeperNode.isHissing = false
                    creeperNode.fuseProgress = 0
                    creeperNode.showOverheadEmoji("🙀 으악 고양이다!", duration: 2.0)
                    SoundAndEffectsManager.shared.play(.alert)
                    state = .fleeingFromCat(timeLeft: 3.5)
                    return
                default:
                    break
                }
            }
        }
        switch state {
        case .stalking:
            creeperNode.isHissing = false
            creeperNode.fuseProgress = 0
            creeperNode.walkSpeed = stalkSpeed
            creeperNode.modelRoot.eulerAngles.y = dirToPlayer > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            // Move towards player
            creeperPhysics.position.x += dirToPlayer * stalkSpeed * dt

            // Check if close enough to start hissing
            if dist < attackProximity {
                creeperNode.showOverheadEmoji("⚠️ Sssss...", duration: 2.0)
                SoundAndEffectsManager.shared.play(.ignite)
                state = .hissing(fuseElapsed: 0)
            }

        case .hissing(var elapsed):
            elapsed += Double(dt)
            creeperNode.walkSpeed = 0
            creeperNode.isHissing = true
            let progress = min(1.0, CGFloat(elapsed / fuseDuration))
            creeperNode.fuseProgress = progress

            // Face player during fuse
            creeperNode.modelRoot.eulerAngles.y = dirToPlayer > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            // If player ran away, stop hissing and resume stalking!
            if dist > escapeProximity {
                creeperNode.isHissing = false
                creeperNode.fuseProgress = 0
                state = .stalking
                return
            }

            // Fuse complete -> BOOM!
            if elapsed >= fuseDuration {
                creeperNode.isHissing = false
                creeperNode.showOverheadEmoji("💥 BOOM!", duration: 1.5)
                SoundAndEffectsManager.shared.play(.explode)
                state = .exploded
                onExplode(creeperPos)
                isDespawned = true
            } else {
                state = .hissing(fuseElapsed: elapsed)
            }


        case .fleeingFromCat(var timeLeft):
            timeLeft -= Double(dt)
            creeperNode.isHissing = false
            creeperNode.fuseProgress = 0
            let fleeSpeed = stalkSpeed * 1.85 // 고양이를 피해 전력 질주!
            creeperNode.walkSpeed = fleeSpeed

            // 고양이(또는 플레이어)의 반대 방향으로 질주
            let refPos = catPos ?? playerPos
            let runDir: CGFloat = creeperPos.x >= refPos.x ? 1.0 : -1.0
            creeperNode.modelRoot.eulerAngles.y = runDir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            creeperPhysics.position.x += runDir * fleeSpeed * dt

            if timeLeft <= 0 {
                state = .stalking
            } else {
                state = .fleeingFromCat(timeLeft: timeLeft)
            }
        case .burningPanic(var timeLeft):
            timeLeft -= Double(dt)
            creeperNode.isHissing = false
            creeperNode.walkSpeed = stalkSpeed * 1.6 // Run away fast in panic!
            // Run opposite direction of player
            let runDir: CGFloat = -dirToPlayer
            creeperNode.modelRoot.eulerAngles.y = runDir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            creeperPhysics.position.x += runDir * (stalkSpeed * 1.6) * dt

            if timeLeft <= 0 {
                // Burn damage!
                applyDamage(1, fromPlayerAt: playerPos, weapon: .torch, creeperPhysics: creeperPhysics, creeperNode: creeperNode, onDefeated: onDefeated)
            } else {
                state = .burningPanic(timeLeft: timeLeft)
            }

        case .hurt(let kbVx, var timer):
            timer -= Double(dt)
            creeperPhysics.position.x += kbVx * dt
            creeperNode.walkSpeed = 0

            if timer <= 0 {
                state = .stalking
            } else {
                state = .hurt(knockbackVx: kbVx * 0.9, timer: timer)
            }

        case .dying(var timer):
            timer -= Double(dt)
            creeperNode.isDying = true
            creeperNode.walkSpeed = 0

            if timer <= 0 {
                isDespawned = true
                onDefeated()
            } else {
                state = .dying(timer: timer)
            }

        case .exploded:
            break
        }
    }

    /// 플레이어가 무기나 맨손으로 크리퍼를 공격했을 때 호출
    public func applyDamage(
        _ damage: Int,
        fromPlayerAt playerPos: CGPoint,
        weapon: HeldItem,
        creeperPhysics: PhysicsEngine,
        creeperNode: CreeperNode,
        onDefeated: @escaping () -> Void
    ) {
        guard !isDespawned else { return }

        hp -= damage
        let dx = creeperPhysics.position.x - playerPos.x
        let knockbackDir: CGFloat = dx >= 0 ? 1.0 : -1.0

        // Red hurt flash
        creeperNode.isHurt = true
        creeperNode.hurtTimer = 0.35

        if weapon == .torch && hp > 0 {
            // Torch sets Creeper on fire -> panic run!
            creeperNode.showOverheadEmoji("🔥 치이익!", duration: 1.8)
            SoundAndEffectsManager.shared.play(.ignite)
            state = .burningPanic(timeLeft: 1.5)
            return
        }

        if hp <= 0 {
            // Creeper defeated!
            creeperNode.isHissing = false
            creeperNode.showOverheadEmoji(chooseLootEmoji(weapon: weapon), duration: 2.0)
            SoundAndEffectsManager.shared.play(.pop)
            state = .dying(timer: 0.85)
        } else {
            // Knockback push
            let kbPower: CGFloat = weapon == .diamondPickaxe ? 320.0 : (weapon == .diamondSword ? 240.0 : 160.0)
            SoundAndEffectsManager.shared.play(.pop)
            creeperNode.showOverheadEmoji("💢 -1", duration: 1.2)
            state = .hurt(knockbackVx: knockbackDir * kbPower, timer: 0.28)
        }
    }

    private func chooseLootEmoji(weapon: HeldItem) -> String {
        switch weapon {
        case .diamondSword:
            return "💥 화약 획득!"
        case .diamondPickaxe:
            return "🟢 경험치 +5"
        case .torch:
            return "✨ 처치 완료!"
        default:
            return "💥 화약 획득!"
        }
    }
}
