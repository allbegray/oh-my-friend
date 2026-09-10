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

    public func contains(x: CGFloat, tolerance: CGFloat = 10) -> Bool {
        return x >= (xMin - tolerance) && x <= (xMax + tolerance)
    }
}

// MARK: - Screen & Window Environment Scanner
public final class ScreenEnvironment {
    public static let shared = ScreenEnvironment()

    private init() {}

    /// Get current screen based on point (or main screen)
    public func screen(for point: CGPoint) -> NSScreen {
        return NSScreen.screens.first { NSPointInRect(point, $0.frame) } ?? NSScreen.main ?? NSScreen.screens[0]
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
                title: "Dock"
            ))
        } else {
            // Standard Screen Bottom
            platforms.append(Platform(
                kind: .floor,
                xMin: screenFrame.minX,
                xMax: screenFrame.maxX,
                yTop: screenFrame.minY,
                title: "화면 바닥"
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
                let p = Platform(
                    kind: .window(id: windowId, appName: appName, pid: ownerPid),
                    xMin: max(screenFrame.minX, cgX),
                    xMax: min(screenFrame.maxX, cgX + cgW),
                    yTop: cocoaTopY,
                    title: "\(appName): \(windowTitle)"
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

    public func update(deltaTime dt: CGFloat, platforms: [Platform], screenFrame: CGRect) {
        guard dt > 0 else { return }

        switch state {
        case .dragged:
            // Handled externally via setDragged
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

            // Screen horizontal bounds clamping
            position.x = max(screenFrame.minX + 20, min(screenFrame.maxX - 20, position.x))

        case .airborne:
            // Apply gravity
            velocity.y += gravity * dt
            // Air friction
            velocity.x *= 0.98

            let nextY = position.y + velocity.y * dt
            let nextX = position.x + velocity.x * dt

            // Screen horizontal clamping
            let clampedX = max(screenFrame.minX + 20, min(screenFrame.maxX - 20, nextX))
            if clampedX != nextX {
                velocity.x = -velocity.x * 0.3 // bounce off screen edge
            }

            // Check collision with platforms (moving downward: velocity.y < 0)
            if velocity.y <= 0 {
                var bestLanding: (platform: Platform, y: CGFloat)?

                for p in platforms {
                    // Check horizontal containment
                    guard p.contains(x: clampedX, tolerance: 15) else { continue }

                    // Did we cross the platform surface from above?
                    // previous position.y was at or above platform.yTop, and nextY is at or below platform.yTop
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

            // Bottom-most emergency safety net (below screen bottom)
            let bottomFloor = screenFrame.minY
            if position.y <= bottomFloor {
                position.y = bottomFloor
                velocity.y = 0
                velocity.x = 0
                state = .onGround(platform: Platform(kind: .floor, xMin: screenFrame.minX, xMax: screenFrame.maxX, yTop: bottomFloor, title: "화면 바닥"))
            }
        }

        previousPosition = position
    }
}
