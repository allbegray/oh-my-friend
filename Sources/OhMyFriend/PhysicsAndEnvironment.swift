import AppKit
import CoreGraphics

// MARK: - Platform Types
public struct Platform {
    public enum Kind: Equatable {
        case floor
        case dock
        case window(id: CGWindowID, appName: String, pid: pid_t)

        public static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case (.floor, .floor): return true
            case (.dock, .dock): return true
            case let (.window(id1, _, _), .window(id2, _, _)): return id1 == id2
            default: return false
            }
        }
    }

    public let kind: Kind
    public let xMin: CGFloat
    public let xMax: CGFloat
    public let yTop: CGFloat
    public let title: String
    /// 창문의 아래쪽 끝(Cocoa y). 창문 발판이 아니면 nil
    public let yBottom: CGFloat?

    public func contains(x: CGFloat, tolerance: CGFloat = 10) -> Bool {
        return x >= (xMin - tolerance) && x <= (xMax + tolerance)
    }
}

// MARK: - Screen & Window Environment Scanner
public final class ScreenEnvironment {
    public static let shared = ScreenEnvironment()

    private init() {}

    /// Total bounding box covering all connected displays
    public var totalDesktopBounds: CGRect {
        let screens = NSScreen.screens
        guard let first = screens.first else { return .zero }
        return screens.reduce(first.frame) { $0.union($1.frame) }
    }

    /// Get current screen based on point, finding closest screen if between displays
    public func screen(for point: CGPoint) -> NSScreen {
        let screens = NSScreen.screens
        if let match = screens.first(where: { NSPointInRect(point, $0.frame) }) {
            return match
        }
        // Find closest screen by distance to handle inter-screen gaps or floating-point margins
        var bestScreen = screens.first ?? NSScreen.main ?? NSScreen()
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for s in screens {
            let f = s.frame
            let dx = max(f.minX - point.x, max(0, point.x - f.maxX))
            let dy = max(f.minY - point.y, max(0, point.y - f.maxY))
            let dist = hypot(dx, dy)
            if dist < minDistance {
                minDistance = dist
                bestScreen = s
            }
        }
        return bestScreen
    }

    /// Check if moving horizontally past an edge connects to an adjacent display at height y
    public func hasAdjacentScreen(from screen: NSScreen, onLeft: Bool, atY y: CGFloat) -> Bool {
        let testX = onLeft ? (screen.frame.minX - 12) : (screen.frame.maxX + 12)
        let testPoint = CGPoint(x: testX, y: y)

        for other in NSScreen.screens {
            if other == screen { continue }
            let f = other.frame
            if f.contains(testPoint) {
                return true
            }
            // Allow tolerance for slight monitor height or edge misalignments (±35pt)
            let xClose = onLeft ? (abs(f.maxX - screen.frame.minX) <= 25) : (abs(f.minX - screen.frame.maxX) <= 25)
            let yContained = (y >= f.minY - 35) && (y <= f.maxY + 35)
            if xClose && yContained {
                return true
            }
        }
        return false
    }

    /// Return adjacent display if one exists past the screen edge at height y
    public func adjacentScreen(from screen: NSScreen, onLeft: Bool, atY y: CGFloat) -> NSScreen? {
        let testX = onLeft ? (screen.frame.minX - 12) : (screen.frame.maxX + 12)
        let testPoint = CGPoint(x: testX, y: y)

        for other in NSScreen.screens {
            if other == screen { continue }
            let f = other.frame
            if f.contains(testPoint) {
                return other
            }
            let xClose = onLeft ? (abs(f.maxX - screen.frame.minX) <= 25) : (abs(f.minX - screen.frame.maxX) <= 25)
            let yContained = (y >= f.minY - 35) && (y <= f.maxY + 35)
            if xClose && yContained {
                return other
            }
        }
        return nil
    }

    /// Detect screen bounds, Dock top edge, and on-screen windows
    public func scanPlatforms(for screen: NSScreen, excludingPID: pid_t = getpid()) -> [Platform] {
        var platforms: [Platform] = []

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        // 1. Floor & Dock Platform
        let dockY = visibleFrame.minY
        if dockY > screenFrame.minY + 10 {
            // Bottom Dock
            platforms.append(Platform(
                kind: .dock,
                xMin: screenFrame.minX,
                xMax: screenFrame.maxX,
                yTop: dockY,
                title: "Dock",
                yBottom: nil
            ))
        } else {
            // Standard Screen Bottom
            platforms.append(Platform(
                kind: .floor,
                xMin: screenFrame.minX,
                xMax: screenFrame.maxX,
                yTop: screenFrame.minY,
                title: "화면 바닥",
                yBottom: nil
            ))
        }

        // 2. Application Windows
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return platforms
        }

        guard let primaryScreen = NSScreen.screens.first else {
            return platforms
        }
        let primaryHeight = primaryScreen.frame.height

        for info in windowInfoList {
            // Must be standard app window (layer == 0)
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }

            // Exclude our own app
            let ownerPid = (info[kCGWindowOwnerPID as String] as? pid_t) ?? -1
            if ownerPid == excludingPID {
                continue
            }

            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let cgX = boundsDict["X"] as? CGFloat,
                  let cgY = boundsDict["Y"] as? CGFloat,
                  let cgW = boundsDict["Width"] as? CGFloat,
                  let cgH = boundsDict["Height"] as? CGFloat else {
                continue
            }

            // Exclude tiny windows, icons, or menus
            guard cgW >= 120 && cgH >= 80 else { continue }

            // Exclude windows off-screen
            let windowId = (info[kCGWindowNumber as String] as? CGWindowID) ?? 0
            let appName = (info[kCGWindowOwnerName as String] as? String) ?? "Window"
            let windowTitle = (info[kCGWindowName as String] as? String) ?? appName

            // Convert CG (Top-Left origin) to Cocoa (Bottom-Left origin)
            let cocoaY = primaryHeight - (cgY + cgH)
            let cocoaTopY = cocoaY + cgH // Top titlebar edge

            // Check if within current screen bounds
            let cocoaRect = CGRect(x: cgX, y: cocoaY, width: cgW, height: cgH)
            if screenFrame.intersects(cocoaRect) {
                let desktopBounds = ScreenEnvironment.shared.totalDesktopBounds
                let p = Platform(
                    kind: .window(id: windowId, appName: appName, pid: ownerPid),
                    xMin: max(desktopBounds.minX, cgX),
                    xMax: min(desktopBounds.maxX, cgX + cgW),
                    yTop: cocoaTopY,
                    title: "\(appName): \(windowTitle)",
                    yBottom: max(desktopBounds.minY, cocoaY)
                )
                platforms.append(p)
            }
        }

        return platforms
    }

    /// Current Cocoa-coordinate (bottom-left origin) frame of a window, by CGWindowID
    public func windowCocoaFrame(windowID: CGWindowID) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        guard let info = windowInfoList.first(where: { ($0[kCGWindowNumber as String] as? CGWindowID) == windowID }),
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let cgX = boundsDict["X"] as? CGFloat,
              let cgY = boundsDict["Y"] as? CGFloat,
              let cgW = boundsDict["Width"] as? CGFloat,
              let cgH = boundsDict["Height"] as? CGFloat else {
            return nil
        }
        let primaryHeight = (NSScreen.screens.first?.frame.height) ?? 0
        let cocoaY = primaryHeight - (cgY + cgH)
        return CGRect(x: cgX, y: cocoaY, width: cgW, height: cgH)
    }

    /// 앱(프로세스)의 화면에 보이는 모든 표준 창 (Cocoa 좌표 프레임)
    public func windowsForApp(pid: pid_t) -> [(id: CGWindowID, frame: CGRect)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let primaryHeight = (NSScreen.screens.first?.frame.height) ?? 0
        var result: [(id: CGWindowID, frame: CGRect)] = []

        for info in windowInfoList {
            // 표준 앱 창만 (layer 0), 대상 프로세스의 창
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner == pid else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let cgX = boundsDict["X"] as? CGFloat,
                  let cgY = boundsDict["Y"] as? CGFloat,
                  let cgW = boundsDict["Width"] as? CGFloat,
                  let cgH = boundsDict["Height"] as? CGFloat else {
                continue
            }
            // 작은 팝업/툴팁성 창 제외
            guard cgW >= 100, cgH >= 60 else { continue }

            let windowId = (info[kCGWindowNumber as String] as? CGWindowID) ?? 0
            let cocoaY = primaryHeight - (cgY + cgH)
            result.append((windowId, CGRect(x: cgX, y: cocoaY, width: cgW, height: cgH)))
        }
        return result
    }

    /// Returns Dock rectangle if dock exists on screen
    public func dockRect(for screen: NSScreen) -> CGRect? {
        let full = screen.frame
        let vis = screen.visibleFrame

        if vis.minY > full.minY + 5 {
            // Bottom Dock
            return CGRect(x: full.minX, y: full.minY, width: full.width, height: vis.minY - full.minY)
        } else if vis.minX > full.minX + 5 {
            // Left Dock
            return CGRect(x: full.minX, y: full.minY, width: vis.minX - full.minX, height: full.height)
        } else if vis.maxX < full.maxX - 5 {
            // Right Dock
            return CGRect(x: vis.maxX, y: full.minY, width: full.maxX - vis.maxX, height: full.height)
        }
        return nil
    }
}

// MARK: - Physics State & Engine
public enum PhysicsState {
    case onGround(platform: Platform)
    case airborne
    case dragged
    case climbing
}

public final class PhysicsEngine {
    public var position: CGPoint // Feet anchor position in Cocoa screen coordinates
    public var velocity: CGPoint = .zero

    public private(set) var state: PhysicsState = .airborne
    public let gravity: CGFloat = -1800.0 // Points / sec^2
    public var currentPlatform: Platform? {
        if case let .onGround(p) = state { return p }
        return nil
    }

    private var previousPosition: CGPoint

    public init(initialPosition: CGPoint) {
        self.position = initialPosition
        self.previousPosition = initialPosition
    }

    public func setDragged(at point: CGPoint) {
        state = .dragged
        velocity = CGPoint(
            x: (point.x - position.x) * 15.0,
            y: (point.y - position.y) * 15.0
        )
        position = point
        previousPosition = point
    }

    public func releaseDrag(throwVelocity: CGPoint) {
        velocity = throwVelocity
        state = .airborne
    }

    public func jump(impulse: CGFloat = 450) {
        if case .onGround = state {
            velocity.y = impulse
            state = .airborne
        }
    }

    /// TNT 폭발 넉백 등 외부 힘으로 즉시 튕겨나간다
    public func launch(vx: CGFloat, vy: CGFloat) {
        velocity = CGPoint(x: vx, y: vy)
        state = .airborne
    }

    /// 사다리 등반 시작: 중력·착지 판정을 멈추고 y를 행동 컨트롤러가 직접 구동한다
    public func beginClimb() {
        velocity = .zero
        state = .climbing
    }

    /// 등반 중 사다리에서 손을 놓아 그대로 낙하시킨다
    public func releaseClimb() {
        velocity = .zero
        state = .airborne
    }

    /// 사다리 등반 완료: 목적지 발판 위(창문 위쪽 끝)에 올라선다
    public func endClimb(on platform: Platform) {
        position.y = platform.yTop
        velocity = .zero
        previousPosition = position
        state = .onGround(platform: platform)
    }

    public func update(deltaTime dt: CGFloat, platforms: [Platform], screenFrame: CGRect) {
        let sc = ScreenEnvironment.shared.screen(for: position)
        update(deltaTime: dt, platforms: platforms, screen: sc)
    }

    public func update(deltaTime dt: CGFloat, platforms: [Platform], screen: NSScreen) {
        guard dt > 0 else { return }
        let screenFrame = screen.frame

        switch state {
        case .dragged:
            // Handled externally via setDragged
            return

        case .climbing:
            // 등반 중: 위치는 CharacterBehaviorController가 직접 구동한다
            return

        case .onGround(let platform):
            // Check if current platform is still valid & character is within X bounds
            let tolerance: CGFloat = 12
            let stillOnX = position.x >= (platform.xMin - tolerance) && position.x <= (platform.xMax + tolerance)

            // Verify if platform still exists at similar Y height (e.g. window moved or closed)
            let matchingPlatform = platforms.first { p in
                p.kind == platform.kind && abs(p.yTop - platform.yTop) < 30
            }

            if stillOnX, let validPlatform = matchingPlatform {
                // Stick to the platform top (even if window moved slightly)
                position.y = validPlatform.yTop
                velocity.y = 0
                state = .onGround(platform: validPlatform)
            } else {
                // Slipped off or window disappeared -> Fall!
                state = .airborne
                velocity.y = 0
            }

            // Multi-monitor aware horizontal bounds clamping:
            // If an adjacent screen exists on this side, let the character step into the next monitor!
            let canPassLeft = ScreenEnvironment.shared.hasAdjacentScreen(from: screen, onLeft: true, atY: position.y)
            let canPassRight = ScreenEnvironment.shared.hasAdjacentScreen(from: screen, onLeft: false, atY: position.y)

            if !canPassLeft && position.x < screenFrame.minX + 20 {
                position.x = screenFrame.minX + 20
            } else if !canPassRight && position.x > screenFrame.maxX - 20 {
                position.x = screenFrame.maxX - 20
            }

        case .airborne:
            // Apply gravity
            velocity.y += gravity * dt
            // Air friction
            velocity.x *= 0.98

            let nextY = position.y + velocity.y * dt
            let nextX = position.x + velocity.x * dt

            // Multi-monitor aware horizontal clamping & bouncing
            let canPassLeft = ScreenEnvironment.shared.hasAdjacentScreen(from: screen, onLeft: true, atY: nextY)
            let canPassRight = ScreenEnvironment.shared.hasAdjacentScreen(from: screen, onLeft: false, atY: nextY)

            var clampedX = nextX
            if !canPassLeft && nextX < screenFrame.minX + 20 {
                clampedX = screenFrame.minX + 20
                velocity.x = -velocity.x * 0.3 // bounce off outer edge
            } else if !canPassRight && nextX > screenFrame.maxX - 20 {
                clampedX = screenFrame.maxX - 20
                velocity.x = -velocity.x * 0.3 // bounce off outer edge
            }

            // Check collision with platforms (moving downward: velocity.y < 0)
            if velocity.y <= 0 {
                var bestLanding: (platform: Platform, y: CGFloat)?

                for p in platforms {
                    // Check horizontal containment
                    guard p.contains(x: clampedX, tolerance: 15) else { continue }

                    // Did we cross the platform surface from above?
                    if position.y >= (p.yTop - 15) && nextY <= (p.yTop + 5) {
                        if let best = bestLanding {
                            if p.yTop > best.y {
                                bestLanding = (p, p.yTop)
                            }
                        } else {
                            bestLanding = (p, p.yTop)
                        }
                    }
                }

                if let landing = bestLanding {
                    position.y = landing.platform.yTop
                    position.x = clampedX
                    velocity.y = 0
                    velocity.x = 0
                    state = .onGround(platform: landing.platform)
                    previousPosition = position
                    return
                }
            }

            position.x = clampedX
            position.y = nextY

            // Multi-monitor aware floor safety net:
            // Check floor of whichever display the character is currently over
            let activeScreen = ScreenEnvironment.shared.screen(for: CGPoint(x: clampedX, y: nextY))
            let bottomFloor = activeScreen.frame.minY
            if nextY <= bottomFloor {
                position.y = bottomFloor
                position.x = clampedX
                velocity.y = 0
                velocity.x = 0
                state = .onGround(platform: Platform(kind: .floor, xMin: activeScreen.frame.minX, xMax: activeScreen.frame.maxX, yTop: bottomFloor, title: "화면 바닥", yBottom: nil))
            }
        }

        previousPosition = position
    }
}
