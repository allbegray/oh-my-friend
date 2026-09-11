import AppKit
import CoreGraphics
import Foundation

public enum PetState {
    case idle(timeLeft: TimeInterval)
    case follow(targetX: CGFloat)
    case sit
    case sleep
}

public final class PetBehaviorController {
    public private(set) var state: PetState = .idle(timeLeft: 1.5)

    public var isSitting: Bool = false
    public var isSleeping: Bool = false
    public var isTeleporting: Bool = false

    private var walkSpeed: CGFloat = 85.0
    private var idleBlinkTimer: TimeInterval = 0
    private var danceTimer: TimeInterval = 0
    private var danceBeatTimer: TimeInterval = 0
    private var wheatLureTimer: TimeInterval = 0
    public var speedMultiplier: CGFloat = 1.0

    public init() {}

    public func startDancing(duration: TimeInterval = 8.0) {
        danceTimer = duration
        danceBeatTimer = 0
    }

    public func enticeWithWheat(duration: TimeInterval = 12.0) {
        wheatLureTimer = duration
    }

    public func update(
        deltaTime dt: CGFloat,
        petPhysics: PhysicsEngine,
        petNode: PetNode,
        playerPos: CGPoint,
        playerIsSitting: Bool,
        playerIsSleeping: Bool,
        playerDirection: CGFloat,
        screen: NSScreen,
        platforms: [Platform]
    ) {
        let petPos = petPhysics.position
        let dx = playerPos.x - petPos.x
        let dy = playerPos.y - petPos.y
        let distance = hypot(dx, dy)

        // 1. Teleport if too far away (> 750 pt) or completely lost
        if distance > 750.0 {
            teleport(to: playerPos, playerDirection: playerDirection, petPhysics: petPhysics, petNode: petNode)
            return
        }

        // 2. Sync with Player Sleeping
        if danceTimer > 0 {
            danceTimer -= dt
            danceBeatTimer -= dt
            if danceBeatTimer <= 0 {
                danceBeatTimer = 0.45
                petPhysics.jump(impulse: 130)
                petNode.showOverheadEmoji("🎶", duration: 0.8)
            }
            if danceTimer <= 0 {
                petNode.walkSpeed = 0
                state = .idle(timeLeft: 1.0)
                return
            }
        }
        if wheatLureTimer > 0 {
            wheatLureTimer -= dt
        }
        if playerIsSleeping {
            petNode.isSleeping = true
            petNode.isSitting = false
            petNode.walkSpeed = 0
            isSleeping = true
            isSitting = false
            state = .sleep
            // Place near foot of the bed
            let targetFootX = playerPos.x + (playerDirection > 0 ? -45 : 45)
            if abs(petPhysics.position.x - targetFootX) > 15 {
                petPhysics.position.x = targetFootX
            }
            return
        } else if isSleeping {
            // Woke up with player!
            isSleeping = false
            petNode.isSleeping = false
            petNode.showOverheadEmoji(petNode.kind.clickEmoji, duration: 1.5)
            SoundAndEffectsManager.shared.play(.pop)
            state = .idle(timeLeft: 1.0)
        }

        // 3. Sync with Player Sitting (or Pet-commanded Sit)
        if playerIsSitting || isSitting {
            petNode.isSitting = true
            petNode.isSleeping = false
            petNode.walkSpeed = 0
            state = .sit
            // Face the same direction or look towards player
            petNode.modelRoot.eulerAngles.y = dx > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            return
        } else {
            petNode.isSitting = false
        }

        // 4. Follow Player Behavior
        let stopDistance: CGFloat = 75.0
        let runThreshold: CGFloat = 200.0

        if distance > stopDistance {
            let dir: CGFloat = dx > 0 ? 1.0 : -1.0
            let isRunning = distance > runThreshold
            var speed: CGFloat = isRunning ? 150.0 : 85.0
            speed *= speedMultiplier
            if wheatLureTimer > 0 {
                speed *= 1.4
                if Int(wheatLureTimer * 2.0) % 4 == 0 {
                    petNode.showOverheadEmoji("👀✨", duration: 0.7)
                }
            }

            petNode.isRunning = isRunning
            petNode.walkSpeed = speed
            petNode.modelRoot.eulerAngles.y = dir > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)

            petPhysics.position.x += dir * speed * dt
            state = .follow(targetX: playerPos.x)
        } else {
            // Reached player, chill and watch
            petNode.isRunning = false
            petNode.walkSpeed = 0

            // Look up at player's head
            petNode.modelRoot.eulerAngles.y = dx > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            petNode.targetHeadPitch = -0.25 // Look slightly up

            idleBlinkTimer += dt
            if idleBlinkTimer > 8.0 {
                idleBlinkTimer = 0
                petNode.showOverheadEmoji(petNode.kind.sitEmoji, duration: 1.5)
            }
            state = .idle(timeLeft: 1.0)
        }
    }

    public func teleport(
        to playerPos: CGPoint,
        playerDirection: CGFloat,
        petPhysics: PhysicsEngine,
        petNode: PetNode
    ) {
        let spawnOffset: CGFloat = playerDirection > 0 ? -65.0 : 65.0
        petPhysics.position = CGPoint(x: playerPos.x + spawnOffset, y: playerPos.y)
        petPhysics.velocity = .zero
        petNode.showOverheadEmoji("✨", duration: 1.8)
        SoundAndEffectsManager.shared.play(.pop)
    }

    public func handlePetClicked(petNode: PetNode) {
        // Toggle Sit / Stand command
        isSitting.toggle()
        petNode.isSitting = isSitting
        let emoji = isSitting ? "🪑" : petNode.kind.heartEmoji
        petNode.showOverheadEmoji(emoji, duration: 1.8)
        SoundAndEffectsManager.shared.play(.heart)
    }
}
