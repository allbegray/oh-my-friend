import AppKit
import CoreGraphics
import Foundation

public enum EndermanState {
    case roaming(direction: CGFloat, walkTimer: TimeInterval)
    case staring(duration: TimeInterval)
    case enraged(chargeTimer: TimeInterval, teleportCooldown: TimeInterval)
    case hurt(knockbackVx: CGFloat, timer: TimeInterval)
    case dying(timer: TimeInterval)
}

public final class EndermanBehaviorController {
    public private(set) var state: EndermanState = .roaming(direction: 1.0, walkTimer: 3.0)
    public private(set) var hp: Int = 4
    public var isDespawned: Bool = false

    /// 엔더맨 생존 여부 (사망 진행 중일 때는 false)
    public var isAlive: Bool {
        if isDespawned || hp <= 0 { return false }
        switch state {
        case .dying:
            return false
        default:
            return true
        }
    }

    public var isEnraged: Bool {
        if case .enraged = state { return true }
        return false
    }

    private let roamSpeed: CGFloat = 45.0
    private let chargeSpeed: CGFloat = 175.0
    private var pumpkinConfusedCooldown: TimeInterval = 0

    public init() {}

    public func update(
        deltaTime dt: CGFloat,
        endermanPhysics: PhysicsEngine,
        endermanNode: EndermanNode,
        playerPos: CGPoint,
        cursorPos: CGPoint,
        screen: NSScreen,
        onDefeated: @escaping () -> Void
    ) {
        guard !isDespawned else { return }

        let endermanPos = endermanPhysics.position
        let headScreenPos = CGPoint(x: endermanPos.x, y: endermanPos.y + 105.0)
        let distCursorToHead = hypot(cursorPos.x - headScreenPos.x, cursorPos.y - headScreenPos.y)
        let isCursorHoveringHead = distCursorToHead < 48.0

        let dxToPlayer = playerPos.x - endermanPos.x
        let dirToPlayer: CGFloat = dxToPlayer >= 0 ? 1.0 : -1.0

        switch state {
        case .roaming(var dir, var timer):
            timer -= Double(dt)
            endermanNode.isStaring = false
            endermanNode.isEnraged = false
            endermanNode.walkSpeed = roamSpeed
            endermanNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            endermanPhysics.position.x += dir * roamSpeed * dt
            pumpkinConfusedCooldown -= Double(dt)

            // Check eye contact with cursor!
            if isCursorHoveringHead && PumpkinWard.shared.isWorn {
                if pumpkinConfusedCooldown <= 0 {
                    pumpkinConfusedCooldown = 3.0
                    endermanNode.showOverheadEmoji("🎃 ...?", duration: 1.5)
                }
            } else if isCursorHoveringHead {
                endermanNode.walkSpeed = 0
                endermanNode.isStaring = true
                endermanNode.showOverheadEmoji("👁️ 쉬이익...!", duration: 1.8)
                SoundAndEffectsManager.shared.play(.alert)
                state = .staring(duration: 0)
                return
            }

            // Screen boundary turning
            if endermanPhysics.position.x <= screen.frame.minX + 40 && dir < 0 {
                dir = 1.0
            } else if endermanPhysics.position.x >= screen.frame.maxX - 40 && dir > 0 {
                dir = -1.0
            }

            if timer <= 0 {
                timer = Double.random(in: 2.5...5.0)
                dir = Bool.random() ? 1.0 : -1.0
            }
            state = .roaming(direction: dir, walkTimer: timer)

        case .staring(var duration):
            duration += Double(dt)
            endermanNode.walkSpeed = 0
            endermanNode.isStaring = true
            endermanNode.isEnraged = false

            // Face the cursor
            let dxCursor = cursorPos.x - endermanPos.x
            endermanNode.modelRoot.eulerAngles.y = dxCursor >= 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            // If user stares for > 1.2s OR looks away after staring -> ENRAGE!
            if duration >= 1.2 || (!isCursorHoveringHead && duration > 0.4) {
                endermanNode.isStaring = false
                endermanNode.isEnraged = true
                endermanNode.isCarryingBlock = false // Drops block in rage!
                endermanNode.showOverheadEmoji("😡 캬아악!!", duration: 2.0)
                SoundAndEffectsManager.shared.play(.alert)
                state = .enraged(chargeTimer: 0, teleportCooldown: 2.5)
            } else {
                state = .staring(duration: duration)
            }

        case .enraged(var chargeTimer, var teleportCooldown):
            chargeTimer += Double(dt)
            teleportCooldown -= Double(dt)
            endermanNode.walkSpeed = chargeSpeed
            endermanNode.isEnraged = true

            // Charge toward player!
            endermanNode.modelRoot.eulerAngles.y = dirToPlayer > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            endermanPhysics.position.x += dirToPlayer * chargeSpeed * dt

            // Periodic teleportation behind or in front of player
            if teleportCooldown <= 0 {
                teleportCooldown = Double.random(in: 2.2...3.5)
                teleport(near: playerPos, screen: screen, endermanPhysics: endermanPhysics, endermanNode: endermanNode)
            }

            state = .enraged(chargeTimer: chargeTimer, teleportCooldown: teleportCooldown)

        case .hurt(let kbVx, var timer):
            timer -= Double(dt)
            endermanPhysics.position.x += kbVx * dt
            endermanNode.walkSpeed = 0

            if timer <= 0 {
                state = .enraged(chargeTimer: 0, teleportCooldown: 1.5)
            } else {
                state = .hurt(knockbackVx: kbVx * 0.88, timer: timer)
            }

        case .dying(var timer):
            timer -= Double(dt)
            endermanNode.isDying = true
            endermanNode.walkSpeed = 0

            if timer <= 0 {
                isDespawned = true
                onDefeated()
            } else {
                state = .dying(timer: timer)
            }
        }
    }

    public func teleport(
        near playerPos: CGPoint,
        screen: NSScreen,
        endermanPhysics: PhysicsEngine,
        endermanNode: EndermanNode
    ) {
        let spawnOffset: CGFloat = Bool.random() ? -120.0 : 120.0
        let targetX = max(screen.frame.minX + 60, min(screen.frame.maxX - 60, playerPos.x + spawnOffset))
        endermanPhysics.position.x = targetX
        endermanPhysics.velocity = .zero
        endermanNode.showOverheadEmoji("🟣", duration: 1.2)
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func applyDamage(
        _ damage: Int,
        fromPlayerAt playerPos: CGPoint,
        weapon: HeldItem,
        endermanPhysics: PhysicsEngine,
        endermanNode: EndermanNode,
        screen: NSScreen,
        onDefeated: @escaping () -> Void
    ) {
        guard isAlive else { return }

        hp -= damage
        let dx = endermanPhysics.position.x - playerPos.x
        let knockbackDir: CGFloat = dx >= 0 ? 1.0 : -1.0

        if hp <= 0 {
            hp = 0
            endermanNode.showOverheadEmoji("🔮 엔더 진주 획득!", duration: 2.5)
            SoundAndEffectsManager.shared.play(.heart)
            state = .dying(timer: 0.85)
        } else {
            // Take damage and teleport to surprise player!
            SoundAndEffectsManager.shared.play(.pop)
            endermanNode.showOverheadEmoji("💢 -1", duration: 1.0)
            teleport(near: playerPos, screen: screen, endermanPhysics: endermanPhysics, endermanNode: endermanNode)
            state = .hurt(knockbackVx: knockbackDir * 180.0, timer: 0.22)
        }
    }
}
