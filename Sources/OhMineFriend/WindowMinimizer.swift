import AppKit
import ApplicationServices
import CoreGraphics

/// macOS 손쉬운 사용(Accessibility) API 및 AppleScript를 활용하여 창을 Dock으로 안전하게 최소화하는 매니저
public final class WindowMinimizer {
    public static let shared = WindowMinimizer()

    public var isAccessibilityTrusted: Bool {
        return AXIsProcessTrusted()
    }

    private init() {}

    /// 대상 윈도우(CGWindowID / PID)를 시스템 Dock으로 압축 최소화(지니/크기조절 효과)
    @discardableResult
    public func minimize(windowID: CGWindowID, pid: pid_t) -> Bool {
        // 1. Accessibility API 우선 시도
        let appRef = AXUIElementCreateApplication(pid)
        var windowsValue: AnyObject?
        let copyRes = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsValue)

        if copyRes == .success, let windows = windowsValue as? [AXUIElement] {
            let targetFrame = ScreenEnvironment.shared.windowCocoaFrame(windowID: windowID)

            for win in windows {
                // 프레임 오차 15pt 이내인 윈도우 매칭 시도
                if let targetFrame = targetFrame {
                    var posValue: AnyObject?
                    var sizeValue: AnyObject?
                    if AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posValue) == .success,
                       AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeValue) == .success {
                        var pt = CGPoint.zero
                        var sz = CGSize.zero
                        if let posVal = posValue, let sizeVal = sizeValue {
                            AXValueGetValue(posVal as! AXValue, .cgPoint, &pt)
                            AXValueGetValue(sizeVal as! AXValue, .cgSize, &sz)

                            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                            let winCocoaY = primaryHeight - (pt.y + sz.height)
                            let winRect = CGRect(x: pt.x, y: winCocoaY, width: sz.width, height: sz.height)

                            if abs(winRect.origin.x - targetFrame.origin.x) < 20 &&
                               abs(winRect.size.width - targetFrame.size.width) < 20 {
                                if performMinimize(on: win) {
                                    return true
                                }
                            }
                        }
                    }
                }

                // 프레임 매칭 실패 시 첫 번째 활성 윈도우 최소화
                if performMinimize(on: win) {
                    return true
                }
            }
        }

        // 2. AppleScript 폴백 시도
        let scriptSource = """
        tell application "System Events"
            try
                tell (first process whose unix id is \(pid))
                    set value of attribute "AXMinimized" of (first window) to true
                end tell
            end try
        end tell
        """
        var errorDict: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&errorDict)
            return errorDict == nil
        }

        return false
    }

    private func performMinimize(on window: AXUIElement) -> Bool {
        // 1. kAXMinimizedAttribute 속성 직접 설정
        let setRes = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        if setRes == .success {
            return true
        }

        // 2. 최소화 버튼 누르기 액션 폴백
        var btnValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &btnValue) == .success,
           let btn = btnValue {
            let pressRes = AXUIElementPerformAction(btn as! AXUIElement, kAXPressAction as CFString)
            if pressRes == .success {
                return true
            }
        }

        return false
    }
}
