import AppKit
import CoreGraphics
import SceneKit

public enum BehaviorMode: String, CaseIterable {
    case autonomous = "자유 배회 (Autonomous)"
    case followCursor = "커서 따라가기 (Follow Cursor)"
    case chill = "멍때리기 (Stay & Chill)"
}

public final class CharacterBehaviorController {
    public enum State {
        case idle(timeLeft: TimeInterval)
        case lookAround(timeLeft: TimeInterval, targetYaw: CGFloat)
        case walk(direction: CGFloat, targetX: CGFloat, duration: TimeInterval, lastX: CGFloat, stuckTime: TimeInterval)
        case sit(timeLeft: TimeInterval)
        case poke(timeLeft: TimeInterval, label: String)
        case wave(timeLeft: TimeInterval)
        case sneakDance(repsLeft: Int, isDown: Bool, timer: TimeInterval)
        case placeAndMineBlock(timeLeft: TimeInterval, isMining: Bool)
        case eating(timeLeft: TimeInterval)
        case sleep(duration: TimeInterval, zzzTimer: TimeInterval)
        case backflip(progress: CGFloat)
        case attack(timeLeft: TimeInterval)
        case fall
        case dragged
        case landedCrouch(timeLeft: TimeInterval)
    }

    public private(set) var state: State = .idle(timeLeft: 2.0)
    public var mode: BehaviorMode = .autonomous

    // Tuning parameters
    public var walkSpeed: CGFloat = 85.0 // points/sec
    private var wasAirborne: Bool = false

    // System Cursor Inactivity Tracking for Sleep
    private var lastCursorPos: CGPoint = .zero
    private var userIdleTime: TimeInterval = 0
    private let idleSleepThreshold: TimeInterval = 45.0 // Sleep after 45s of no mouse movement

    // Near Cursor Proximity Tracking for Wave
    private var cursorHoverTimer: TimeInterval = 0

    // Pickaxe attack bookkeeping
    private var attackDuration: TimeInterval = 0
    private var attackTarget: Platform?
    private var attackCompletion: ((Platform?) -> Void)?

    public init() {}

    // MARK: - Direct Triggers (Called by View, Menu or Shortcuts)
    public func triggerBackflip(physics: PhysicsEngine, characterNode: MinecraftCharacterNode) {
        physics.jump(impulse: 560)
        SoundAndEffectsManager.shared.play(.jump)
        characterNode.showOverheadEmoji("🤸‍♂️", duration: 1.5)
        state = .backflip(progress: 0)
    }

    public func triggerSneakDance(characterNode: MinecraftCharacterNode) {
        characterNode.showOverheadEmoji("🕺", duration: 2.0)
        SoundAndEffectsManager.shared.play(.pop)
        state = .sneakDance(repsLeft: 4, isDown: true, timer: 0.15)
    }

    public func triggerWave(characterNode: MinecraftCharacterNode) {
        characterNode.showOverheadEmoji("👋", duration: 2.0)
        SoundAndEffectsManager.shared.play(.heart)
        state = .wave(timeLeft: 2.5)
    }

    public func triggerSleep(characterNode: MinecraftCharacterNode) {
        characterNode.showOverheadEmoji("💤", duration: 2.5)
        state = .sleep(duration: 30.0, zzzTimer: 1.5)
    }

    public func triggerEating(characterNode: MinecraftCharacterNode) {
        characterNode.showOverheadEmoji("🍎", duration: 2.5)
        state = .eating(timeLeft: 2.8)
    }

    public func triggerPlaceAndMine(characterNode: MinecraftCharacterNode) {
        characterNode.showOverheadEmoji("⛏️", duration: 2.5)
        characterNode.placedBlockNode.isHidden = false
        SoundAndEffectsManager.shared.play(.pop)
        state = .placeAndMineBlock(timeLeft: 3.0, isMining: false)
    }

    public func handleCharacterClicked(characterNode: MinecraftCharacterNode) {
        SoundAndEffectsManager.shared.play(.heart)
        characterNode.showOverheadEmoji("❤️", duration: 1.8)

        // Wake up if sleeping
        if case .sleep = state {
            wakeUp(characterNode: characterNode)
        } else {
            // Little playful hop
            triggerSneakDance(characterNode: characterNode)
        }
    }

    private func wakeUp(characterNode: MinecraftCharacterNode) {
        characterNode.isSleeping = false
        characterNode.showOverheadEmoji("❗", duration: 1.5)
        SoundAndEffectsManager.shared.play(.alert)
        state = .idle(timeLeft: 1.5)
    }

    // MARK: - Pickaxe Attack (앱 창 부수기)
    public var isAttacking: Bool {
        if case .attack = state { return true }
        return false
    }

    /// Pickaxe attack progress 0...1 while attacking, nil otherwise
    public var attackProgress: CGFloat? {
        guard case let .attack(timeLeft) = state, attackDuration > 0 else { return nil }
        return min(1, max(0, 1 - CGFloat(timeLeft / attackDuration)))
    }

    /// Start a pickaxe attack. `completion` fires once when the attack ends
    /// naturally (with the target platform) or is interrupted (with nil).
    @discardableResult
    public func startPickaxeAttack(
        on platform: Platform,
        duration: TimeInterval = 2.0,
        completion: @escaping (Platform?) -> Void
    ) -> Bool {
        guard !isAttacking else { return false }
        attackDuration = duration
        attackTarget = platform
        attackCompletion = completion
        state = .attack(timeLeft: duration)
        return true
    }

    // MARK: - Main Update Loop
    public func update(
        deltaTime dt: TimeInterval,
        physics: PhysicsEngine,
        characterNode: MinecraftCharacterNode,
        platforms: [Platform],
        screen: NSScreen,
        cursorPos: CGPoint
    ) {
        let charPos = physics.position
        let currentPlatform = physics.currentPlatform

        // 1. Mouse Activity & Proximity Tracking
        let cursorDelta = hypot(cursorPos.x - lastCursorPos.x, cursorPos.y - lastCursorPos.y)
        if cursorDelta > 2.0 {
            userIdleTime = 0
            // If sleeping and user moves mouse significantly, wake up!
            if case .sleep = state {
                wakeUp(characterNode: characterNode)
            }
        } else {
            userIdleTime += dt
        }
        lastCursorPos = cursorPos

        // Automatic Nap after long inactivity
        if userIdleTime >= idleSleepThreshold {
            if case .sleep = state {
                // already sleeping
            } else if case .onGround = physics.state {
                triggerSleep(characterNode: characterNode)
                userIdleTime = 0
            }
        }

        // Proximity detection for greeting wave (within 45pt of head)
        let headScreenPos = CGPoint(x: charPos.x, y: charPos.y + 65)
        let distToHead = hypot(cursorPos.x - headScreenPos.x, cursorPos.y - headScreenPos.y)
        if distToHead < 48.0 && !characterNode.isSleeping && !characterNode.isBeingDragged {
            cursorHoverTimer += dt
            if cursorHoverTimer > 0.6 {
                cursorHoverTimer = 0
                if case .wave = state {} else {
                    triggerWave(characterNode: characterNode)
                }
            }
        } else {
            cursorHoverTimer = 0
        }

        // 2. Head Orientation
        updateHeadLookAt(
            charPos: charPos,
            cursorPos: cursorPos,
            characterNode: characterNode
        )

        // 3. Physics Overrides (Dragged / Airborne)
        if case .dragged = physics.state {
            interruptAttackIfActive()
            state = .dragged
            characterNode.isBeingDragged = true
            characterNode.isFalling = false
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isBackflipping = false
            characterNode.isEating = false
            characterNode.placedBlockNode.isHidden = true
            characterNode.isMining = false
            characterNode.walkSpeed = 0
            wasAirborne = true
            return
        }

        if case .airborne = physics.state {
            interruptAttackIfActive()

            if case .backflip(var progress) = state {
                // Keep backflip rotating
                progress += CGFloat(dt) * 4.2
                characterNode.backflipAngle = -progress * CGFloat.pi * 2.0
                characterNode.isBackflipping = true
                characterNode.isFalling = false
                state = .backflip(progress: progress)
                wasAirborne = true
                return
            }
            state = .fall
            characterNode.isBeingDragged = false
            characterNode.isFalling = true
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isBackflipping = false
            characterNode.isEating = false
            characterNode.placedBlockNode.isHidden = true
            characterNode.isMining = false
            characterNode.walkSpeed = 0
            wasAirborne = true
            return
        }

        // Just landed!
        if wasAirborne {
            wasAirborne = false
            state = .landedCrouch(timeLeft: 0.35)
            characterNode.isFalling = false
            characterNode.isBackflipping = false
            characterNode.isMining = false
            characterNode.walkSpeed = 0
            SoundAndEffectsManager.shared.play(.land)
        }

        // 4. Reset general flags
        characterNode.isBeingDragged = false
        characterNode.isFalling = false
        characterNode.isMining = false

        // 5. Finite State Machine
        switch state {
        case .landedCrouch(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = true
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isEating = false
            if timeLeft <= 0 {
                characterNode.isSitting = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .landedCrouch(timeLeft: timeLeft)
            }

        case .idle(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isEating = false

            if timeLeft <= 0 {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .idle(timeLeft: timeLeft)
            }

        case .lookAround(var timeLeft, let targetYaw):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isEating = false
            characterNode.targetHeadYaw = targetYaw

            if timeLeft <= 0 {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .lookAround(timeLeft: timeLeft, targetYaw: targetYaw)
            }

        case .wave(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isWaving = true
            characterNode.isPoking = false
            characterNode.isSneaking = false

            if timeLeft <= 0 {
                characterNode.isWaving = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .wave(timeLeft: timeLeft)
            }

        case .sneakDance(var repsLeft, var isDown, var timer):
            timer -= dt
            characterNode.walkSpeed = 0
            characterNode.isSneaking = isDown

            if timer <= 0 {
                if isDown {
                    isDown = false
                    timer = 0.15
                } else {
                    repsLeft -= 1
                    isDown = true
                    timer = 0.15
                    SoundAndEffectsManager.shared.play(.pop)
                }

                if repsLeft <= 0 {
                    characterNode.isSneaking = false
                    chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
                    return
                }
            }
            state = .sneakDance(repsLeft: repsLeft, isDown: isDown, timer: timer)

        case .eating(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isEating = true

            if timeLeft <= 0 {
                characterNode.isEating = false
                characterNode.showOverheadEmoji("😋", duration: 1.5)
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .eating(timeLeft: timeLeft)
            }

        case .placeAndMineBlock(var timeLeft, var isMining):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isPoking = isMining

            if timeLeft < 2.0 && !isMining {
                isMining = true
                SoundAndEffectsManager.shared.play(.pop)
            }

            if timeLeft <= 0 {
                characterNode.placedBlockNode.isHidden = true
                characterNode.isPoking = false
                SoundAndEffectsManager.shared.play(.pop)
                characterNode.showOverheadEmoji("✨", duration: 1.5)
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .placeAndMineBlock(timeLeft: timeLeft, isMining: isMining)
            }

        case .sleep(var duration, var zzzTimer):
            duration -= dt
            zzzTimer -= dt
            characterNode.walkSpeed = 0
            characterNode.isSleeping = true

            if zzzTimer <= 0 {
                zzzTimer = 2.0
                characterNode.showOverheadEmoji("💤", duration: 1.8)
            }

            if duration <= 0 {
                wakeUp(characterNode: characterNode)
            } else {
                state = .sleep(duration: duration, zzzTimer: zzzTimer)
            }

        case .backflip:
            break

        case .walk(let direction, let targetX, var duration, _, var stuckTime):
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isWaving = false
            characterNode.isSneaking = false
            characterNode.isSleeping = false
            characterNode.isEating = false
            characterNode.walkSpeed = 1.0

            let targetBodyYaw: CGFloat = direction > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            characterNode.modelRoot.eulerAngles.y = targetBodyYaw

            let prevX = physics.position.x
            let step = direction * walkSpeed * CGFloat(dt)
            physics.position.x += step

            duration += dt

            let actualMove = abs(physics.position.x - prevX)
            if actualMove < 0.2 {
                stuckTime += dt
            } else {
                stuckTime = 0
            }

            let screenMinX = screen.frame.minX + 35.0
            let screenMaxX = screen.frame.maxX - 35.0
            let hitScreenLeft = (physics.position.x <= screenMinX) && (direction < 0)
            let hitScreenRight = (physics.position.x >= screenMaxX) && (direction > 0)

            var hitPlatformLeft = false
            var hitPlatformRight = false
            if let p = currentPlatform {
                hitPlatformLeft = (physics.position.x <= p.xMin + 30.0) && (direction < 0)
                hitPlatformRight = (physics.position.x >= p.xMax - 30.0) && (direction > 0)
            }

            let reachedTarget = direction > 0 ? (physics.position.x >= targetX) : (physics.position.x <= targetX)
            let isStuck = stuckTime > 0.6 || duration > 6.0

            if hitScreenLeft || hitPlatformLeft {
                handleReachedEdge(
                    isLeft: true,
                    platform: currentPlatform,
                    screen: screen,
                    characterNode: characterNode,
                    physics: physics
                )
            } else if hitScreenRight || hitPlatformRight {
                handleReachedEdge(
                    isLeft: false,
                    platform: currentPlatform,
                    screen: screen,
                    characterNode: characterNode,
                    physics: physics
                )
            } else if reachedTarget || isStuck {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .walk(
                    direction: direction,
                    targetX: targetX,
                    duration: duration,
                    lastX: physics.position.x,
                    stuckTime: stuckTime
                )
            }

        case .sit(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = true
            characterNode.isPoking = false
            characterNode.isSleeping = false

            characterNode.modelRoot.eulerAngles.y = 0

            if timeLeft <= 0 {
                characterNode.isSitting = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .sit(timeLeft: timeLeft)
            }

        case .poke(var timeLeft, _):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isPoking = true

            if timeLeft <= 0 {
                characterNode.isPoking = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .poke(timeLeft: timeLeft, label: "")
            }

        case .attack(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.isMining = true

            if timeLeft <= 0 {
                // Attack finished -> hand the target window over to the break effect
                finishAttack(platform: attackTarget)
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos, characterNode: characterNode)
            } else {
                state = .attack(timeLeft: timeLeft)
            }

        case .fall, .dragged:
            break
        }
    }

    private func interruptAttackIfActive() {
        if case .attack = state {
            finishAttack(platform: nil)
        }
    }

    private func finishAttack(platform: Platform?) {
        guard case .attack = state else { return }
        state = .idle(timeLeft: 0.4)
        attackDuration = 0
        attackTarget = nil
        let completion = attackCompletion
        attackCompletion = nil
        completion?(platform)
    }

    private func chooseNextState(
        physics: PhysicsEngine,
        platforms: [Platform],
        screen: NSScreen,
        cursorPos: CGPoint,
        characterNode: MinecraftCharacterNode
    ) {
        guard let platform = physics.currentPlatform else {
            state = .idle(timeLeft: 1.5)
            return
        }

        switch mode {
        case .chill:
            state = .idle(timeLeft: Double.random(in: 3.0...6.0))
            return

        case .followCursor:
            let dist = cursorPos.x - physics.position.x
            if abs(dist) > 40 {
                let dir: CGFloat = dist > 0 ? 1.0 : -1.0
                let screenMinX = screen.frame.minX + 45
                let screenMaxX = screen.frame.maxX - 45
                let minBound = max(platform.xMin + 35, screenMinX)
                let maxBound = min(platform.xMax - 35, screenMaxX)
                let targetX = min(maxBound, max(minBound, cursorPos.x))
                state = .walk(direction: dir, targetX: targetX, duration: 0, lastX: physics.position.x, stuckTime: 0)
            } else {
                state = .idle(timeLeft: 1.5)
            }
            return

        case .autonomous:
            break
        }

        // Autonomous Decisions (Rich Variety!)
        let roll = Double.random(in: 0...100)

        let screenMinX = screen.frame.minX + 45
        let screenMaxX = screen.frame.maxX - 45
        let minX = max(platform.xMin + 35, screenMinX)
        let maxX = min(platform.xMax - 35, screenMaxX)

        if roll < 15 {
            // Place and mine a block!
            triggerPlaceAndMine(characterNode: characterNode)
        } else if roll < 26 {
            // Eat snack / apple
            triggerEating(characterNode: characterNode)
        } else if roll < 38 {
            // Minecraft Sneak Twerk Dance!
            triggerSneakDance(characterNode: characterNode)
        } else if roll < 52 {
            // Poke Dock or window
            let label = (platform.kind == .dock) ? "Dock 아이콘 툭툭 건드리기" : "창문 노크하기"
            state = .poke(timeLeft: Double.random(in: 1.5...3.0), label: label)
        } else if roll < 68 {
            // Sit down and rest
            state = .sit(timeLeft: Double.random(in: 3.5...7.0))
        } else if roll < 82 {
            // Look around
            let randomYaw = CGFloat.random(in: -0.8...0.8)
            state = .lookAround(timeLeft: Double.random(in: 1.5...3.0), targetYaw: randomYaw)
        } else {
            // Walk
            if maxX > minX {
                let destX = CGFloat.random(in: minX...maxX)
                let dir: CGFloat = destX > physics.position.x ? 1.0 : -1.0
                state = .walk(direction: dir, targetX: destX, duration: 0, lastX: physics.position.x, stuckTime: 0)
            } else {
                state = .idle(timeLeft: 2.0)
            }
        }
    }

    private func handleReachedEdge(
        isLeft: Bool,
        platform: Platform?,
        screen: NSScreen,
        characterNode: MinecraftCharacterNode,
        physics: PhysicsEngine
    ) {
        let roll = Double.random(in: 0...100)

        // 1. 45% chance: Sit down and relax (dangle legs)
        if roll < 45 {
            state = .sit(timeLeft: Double.random(in: 4.0...8.0))
            return
        }

        // 2. 40% chance: Turn around and walk back towards screen center!
        if roll < 85 {
            let turnDirection: CGFloat = isLeft ? 1.0 : -1.0
            let screenMidX = screen.frame.midX
            let safeTargetX: CGFloat
            if let p = platform {
                let pMid = (p.xMin + p.xMax) / 2.0
                safeTargetX = isLeft ? min(screenMidX, pMid + 80) : max(screenMidX, pMid - 80)
            } else {
                safeTargetX = isLeft ? (physics.position.x + 150) : (physics.position.x - 150)
            }

            state = .walk(
                direction: turnDirection,
                targetX: safeTargetX,
                duration: 0,
                lastX: physics.position.x,
                stuckTime: 0
            )
            return
        }

        // 3. 15% chance: Stand and look around or peek over cliff
        if let p = platform, p.kind != .floor && p.kind != .dock {
            state = .poke(timeLeft: 2.5, label: "아래 내려다보기")
        } else {
            let lookAway = isLeft ? CGFloat(0.7) : CGFloat(-0.7)
            state = .lookAround(timeLeft: 2.5, targetYaw: lookAway)
        }
    }

    private func updateHeadLookAt(
        charPos: CGPoint,
        cursorPos: CGPoint,
        characterNode: MinecraftCharacterNode
    ) {
        let headScreenPos = CGPoint(x: charPos.x, y: charPos.y + 65)
        let dx = cursorPos.x - headScreenPos.x
        let dy = cursorPos.y - headScreenPos.y
        let distance = hypot(dx, dy)

        if distance < 1000 && distance > 10 {
            let bodyYaw = characterNode.modelRoot.eulerAngles.y
            var rawYaw = CGFloat(atan2(dx, 150)) - bodyYaw
            rawYaw = max(-1.2, min(1.2, rawYaw))
            characterNode.targetHeadYaw = rawYaw

            var rawPitch = CGFloat(-atan2(dy, 150))
            rawPitch = max(-0.8, min(0.8, rawPitch))
            characterNode.targetHeadPitch = rawPitch
        } else {
            characterNode.targetHeadYaw = 0
            characterNode.targetHeadPitch = 0
        }
    }
}
