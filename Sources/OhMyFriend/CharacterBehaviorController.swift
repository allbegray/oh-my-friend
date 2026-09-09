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
        case fall
        case dragged
        case landedCrouch(timeLeft: TimeInterval)
    }

    public private(set) var state: State = .idle(timeLeft: 2.0)
    public var mode: BehaviorMode = .autonomous

    // Tuning parameters
    public var walkSpeed: CGFloat = 85.0 // points/sec
    private var wasAirborne: Bool = false

    public init() {}

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

        // 1. Update Look-At Cursor (Head Orientation)
        updateHeadLookAt(
            charPos: charPos,
            cursorPos: cursorPos,
            characterNode: characterNode
        )

        // 2. Check Physics Dragged or Falling overrides
        if case .dragged = physics.state {
            state = .dragged
            characterNode.isBeingDragged = true
            characterNode.isFalling = false
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.walkSpeed = 0
            wasAirborne = true
            return
        }

        if case .airborne = physics.state {
            state = .fall
            characterNode.isBeingDragged = false
            characterNode.isFalling = true
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.walkSpeed = 0
            wasAirborne = true
            return
        }

        // Just landed!
        if wasAirborne {
            wasAirborne = false
            state = .landedCrouch(timeLeft: 0.4)
            characterNode.isFalling = false
            characterNode.walkSpeed = 0
        }

        // 3. Finite State Machine when onGround
        characterNode.isBeingDragged = false
        characterNode.isFalling = false

        switch state {
        case .landedCrouch(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = true // slight crouch
            characterNode.isPoking = false
            if timeLeft <= 0 {
                characterNode.isSitting = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
            } else {
                state = .landedCrouch(timeLeft: timeLeft)
            }

        case .idle(var timeLeft):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = false
            characterNode.isPoking = false

            if timeLeft <= 0 {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
            } else {
                state = .idle(timeLeft: timeLeft)
            }

        case .lookAround(var timeLeft, let targetYaw):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.targetHeadYaw = targetYaw

            if timeLeft <= 0 {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
            } else {
                state = .lookAround(timeLeft: timeLeft, targetYaw: targetYaw)
            }

        case .walk(let direction, let targetX, var duration, _, var stuckTime):
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.walkSpeed = 1.0

            // Face the direction of movement
            let targetBodyYaw: CGFloat = direction > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            characterNode.modelRoot.eulerAngles.y = targetBodyYaw

            // Move
            let prevX = physics.position.x
            let step = direction * walkSpeed * CGFloat(dt)
            physics.position.x += step

            duration += dt

            // Check if position was blocked/clamped (stuck check)
            let actualMove = abs(physics.position.x - prevX)
            if actualMove < 0.2 {
                stuckTime += dt
            } else {
                stuckTime = 0
            }

            // Screen boundary check (with comfortable 35pt margin from physical screen edges)
            let screenMinX = screen.frame.minX + 35.0
            let screenMaxX = screen.frame.maxX - 35.0
            let hitScreenLeft = (physics.position.x <= screenMinX) && (direction < 0)
            let hitScreenRight = (physics.position.x >= screenMaxX) && (direction > 0)

            // Platform boundary check
            var hitPlatformLeft = false
            var hitPlatformRight = false
            if let p = currentPlatform {
                hitPlatformLeft = (physics.position.x <= p.xMin + 30.0) && (direction < 0)
                hitPlatformRight = (physics.position.x >= p.xMax - 30.0) && (direction > 0)
            }

            let reachedTarget = direction > 0 ? (physics.position.x >= targetX) : (physics.position.x <= targetX)
            let isStuck = stuckTime > 0.6 || duration > 6.0

            if hitScreenLeft || hitPlatformLeft {
                // Reached left edge
                handleReachedEdge(
                    isLeft: true,
                    platform: currentPlatform,
                    screen: screen,
                    characterNode: characterNode,
                    physics: physics
                )
            } else if hitScreenRight || hitPlatformRight {
                // Reached right edge
                handleReachedEdge(
                    isLeft: false,
                    platform: currentPlatform,
                    screen: screen,
                    characterNode: characterNode,
                    physics: physics
                )
            } else if reachedTarget || isStuck {
                // Reached destination or stuck -> choose next state
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
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

            // Face forward while sitting
            characterNode.modelRoot.eulerAngles.y = 0

            if timeLeft <= 0 {
                characterNode.isSitting = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
            } else {
                state = .sit(timeLeft: timeLeft)
            }

        case .poke(var timeLeft, _):
            timeLeft -= dt
            characterNode.walkSpeed = 0
            characterNode.isPoking = true

            if timeLeft <= 0 {
                characterNode.isPoking = false
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
            } else {
                state = .poke(timeLeft: timeLeft, label: "")
            }

        case .fall, .dragged:
            break
        }
    }

    private func chooseNextState(
        physics: PhysicsEngine,
        platforms: [Platform],
        screen: NSScreen,
        cursorPos: CGPoint
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
            // Walk toward cursor X position if on same horizontal area
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

        // Autonomous Decision
        let roll = Double.random(in: 0...100)

        // Calculate safe walkable bounds
        let screenMinX = screen.frame.minX + 45
        let screenMaxX = screen.frame.maxX - 45
        let minX = max(platform.xMin + 35, screenMinX)
        let maxX = min(platform.xMax - 35, screenMaxX)

        if roll < 22 {
            // Poke Dock icon or window titlebar
            let label = (platform.kind == .dock) ? "Dock 아이콘 툭툭 건드리기" : "창문 노크하기"
            state = .poke(timeLeft: Double.random(in: 1.5...3.0), label: label)
        } else if roll < 45 {
            // Sit down and rest
            state = .sit(timeLeft: Double.random(in: 3.5...7.0))
        } else if roll < 65 {
            // Look around
            let randomYaw = CGFloat.random(in: -0.8...0.8)
            state = .lookAround(timeLeft: Double.random(in: 1.5...3.0), targetYaw: randomYaw)
        } else {
            // Walk to a random spot on the current platform
            if maxX > minX {
                let destX = CGFloat.random(in: minX...maxX)
                let dir: CGFloat = destX > physics.position.x ? 1.0 : -1.0
                state = .walk(direction: dir, targetX: destX, duration: 0, lastX: physics.position.x, stuckTime: 0)
            } else {
                state = .idle(timeLeft: 2.0)
            }
        }
    }

    /// Called when the character reaches the screen edge or window platform edge
    private func handleReachedEdge(
        isLeft: Bool,
        platform: Platform?,
        screen: NSScreen,
        characterNode: MinecraftCharacterNode,
        physics: PhysicsEngine
    ) {
        let roll = Double.random(in: 0...100)

        // 1. If reached edge, 45% chance: Sit down and relax (dangle legs)
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
            // On a floating window edge: peek over cliff
            state = .poke(timeLeft: 2.5, label: "아래 내려다보기")
        } else {
            // On floor/dock edge: stand and look around
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

        // Only track cursor if reasonably close (within 1000 pt)
        if distance < 1000 && distance > 10 {
            // Compute Yaw (Horizontal angle)
            // Note: If modelRoot is turned, we adjust relative to body yaw
            let bodyYaw = characterNode.modelRoot.eulerAngles.y
            var rawYaw = CGFloat(atan2(dx, 150)) - bodyYaw

            // Clamp yaw to natural head rotation range (-70 deg ~ +70 deg)
            rawYaw = max(-1.2, min(1.2, rawYaw))
            characterNode.targetHeadYaw = rawYaw

            // Compute Pitch (Vertical angle: looking up or down)
            var rawPitch = CGFloat(-atan2(dy, 150)) // Looking up dy > 0 -> pitch negative (SceneKit)
            rawPitch = max(-0.8, min(0.8, rawPitch))
            characterNode.targetHeadPitch = rawPitch
        } else {
            // Return to forward
            characterNode.targetHeadYaw = 0
            characterNode.targetHeadPitch = 0
        }
    }
}
