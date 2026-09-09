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
        case walk(direction: CGFloat, targetX: CGFloat)
        case sit(timeLeft: TimeInterval)
        case poke(timeLeft: TimeInterval, label: String)
        case fall
        case dragged
        case landedCrouch(timeLeft: TimeInterval)
    }

    public private(set) var state: State = .idle(timeLeft: 2.0)
    public var mode: BehaviorMode = .autonomous

    // Tuning parameters
    public var walkSpeed: CGFloat = 80.0 // points/sec
    private var stateTimer: TimeInterval = 0
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

        case .walk(let direction, let targetX):
            characterNode.isSitting = false
            characterNode.isPoking = false
            characterNode.walkSpeed = 1.0

            // Face the direction of movement
            let targetBodyYaw: CGFloat = direction > 0 ? (CGFloat.pi / 2.0) : (-CGFloat.pi / 2.0)
            characterNode.modelRoot.eulerAngles.y = targetBodyYaw

            // Move
            let step = direction * walkSpeed * CGFloat(dt)
            physics.position.x += step

            // Check if reached destination or platform edge
            let reachedTarget = direction > 0 ? (physics.position.x >= targetX) : (physics.position.x <= targetX)

            if let platform = currentPlatform {
                // If reached edge of platform
                let isAtLeftEdge = physics.position.x <= platform.xMin + 15
                let isAtRightEdge = physics.position.x >= platform.xMax - 15

                if reachedTarget || (direction < 0 && isAtLeftEdge) || (direction > 0 && isAtRightEdge) {
                    // Decide what to do at edge
                    if isAtLeftEdge || isAtRightEdge {
                        handleReachedPlatformEdge(
                            isLeft: isAtLeftEdge,
                            platform: platform,
                            characterNode: characterNode,
                            physics: physics
                        )
                    } else {
                        chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
                    }
                    return
                }
            } else if reachedTarget {
                chooseNextState(physics: physics, platforms: platforms, screen: screen, cursorPos: cursorPos)
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
                let targetX = min(platform.xMax - 20, max(platform.xMin + 20, cursorPos.x))
                state = .walk(direction: dir, targetX: targetX)
            } else {
                state = .idle(timeLeft: 1.5)
            }
            return

        case .autonomous:
            break
        }

        // Autonomous Decision
        let roll = Double.random(in: 0...100)

        // If on Dock or Window, poke interaction is fun!
        if roll < 20 {
            // Poke Dock icon or window titlebar
            let label = (platform.kind == .dock) ? "Dock 아이콘 툭툭 건드리기" : "윈도우 창 노크하기"
            state = .poke(timeLeft: Double.random(in: 1.5...3.0), label: label)
        } else if roll < 45 {
            // Idle & Look around
            state = .idle(timeLeft: Double.random(in: 2.0...4.0))
        } else if roll < 65 {
            // Look around specifically
            let randomYaw = CGFloat.random(in: -0.8...0.8)
            state = .lookAround(timeLeft: Double.random(in: 1.5...3.0), targetYaw: randomYaw)
        } else if roll < 85 {
            // Walk to a random spot on the current platform
            let margin: CGFloat = 25
            let minX = platform.xMin + margin
            let maxX = platform.xMax - margin
            if maxX > minX {
                let destX = CGFloat.random(in: minX...maxX)
                let dir: CGFloat = destX > physics.position.x ? 1.0 : -1.0
                state = .walk(direction: dir, targetX: destX)
            } else {
                state = .idle(timeLeft: 2.0)
            }
        } else {
            // Walk all the way to an edge to sit!
            let targetEdgeX = Bool.random() ? (platform.xMin + 15) : (platform.xMax - 15)
            let dir: CGFloat = targetEdgeX > physics.position.x ? 1.0 : -1.0
            state = .walk(direction: dir, targetX: targetEdgeX)
        }
    }

    private func handleReachedPlatformEdge(
        isLeft: Bool,
        platform: Platform,
        characterNode: MinecraftCharacterNode,
        physics: PhysicsEngine
    ) {
        let roll = Double.random(in: 0...100)

        if roll < 50 {
            // Sit on edge and dangle legs!
            state = .sit(timeLeft: Double.random(in: 4.0...8.0))
        } else if roll < 75 {
            // Look over the cliff (poke/peek)
            state = .poke(timeLeft: 2.5, label: "아래 내려다보기")
        } else if roll < 90 {
            // Turn around and walk back
            let destX = isLeft ? (platform.xMin + 100) : (platform.xMax - 100)
            state = .walk(direction: isLeft ? 1.0 : -1.0, targetX: destX)
        } else {
            // Little jump off or turn around
            if platform.kind != .floor {
                // Jump off window!
                physics.jump(impulse: 200)
                physics.velocity.x = isLeft ? -100 : 100
                state = .fall
            } else {
                state = .idle(timeLeft: 2.0)
            }
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
