import AppKit
import CoreGraphics

public struct NotificationNagStatus {
    public let shouldNag: Bool
    public let bannerCount: Int
    public let lingeringDuration: TimeInterval
}

/// 방치된 macOS 알림창을 감지하여 캐릭터가 잔소리/구박할 타이밍을 판정하는 모니터
public final class NotificationCenterMonitor {
    public static let shared = NotificationCenterMonitor()

    public var isEnabled: Bool = true
    private var firstSeenBannerTime: TimeInterval?
    private var lastScanTime: TimeInterval = 0
    private var cachedStatus = NotificationNagStatus(shouldNag: false, bannerCount: 0, lingeringDuration: 0)
    private var simulatedNagTriggered: Bool = false

    private init() {}

    /// 수동 시뮬레이션용 트리거 (테스트 또는 메뉴 즉시 실행 시)
    public func triggerSimulatedNag() {
        simulatedNagTriggered = true
    }

    public func resetNagTrigger() {
        simulatedNagTriggered = false
        firstSeenBannerTime = nil
    }

    /// 현재 화면 상단 구석의 알림 배너 존재 여부 및 방치 시간 검사
    public func checkNagStatus(screen: NSScreen) -> NotificationNagStatus {
        guard isEnabled else {
            return NotificationNagStatus(shouldNag: false, bannerCount: 0, lingeringDuration: 0)
        }

        if simulatedNagTriggered {
            simulatedNagTriggered = false
            return NotificationNagStatus(shouldNag: true, bannerCount: 2, lingeringDuration: 8.0)
        }

        let now = ProcessInfo.processInfo.systemUptime
        // 0.5초마다 1회 스캔 (성능 최적화)
        if now - lastScanTime < 0.5 {
            return cachedStatus
        }
        lastScanTime = now

        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return cachedStatus
        }

        let screenFrame = screen.frame
        var bannerCount = 0

        for win in list {
            let pid = (win[kCGWindowOwnerPID as String] as? pid_t) ?? 0
            let app = NSRunningApplication(processIdentifier: pid)
            let bundleId = app?.bundleIdentifier ?? ""
            let owner = (win[kCGWindowOwnerName as String] as? String) ?? ""
            let layer = (win[kCGWindowLayer as String] as? Int) ?? 0

            guard let bounds = win[kCGWindowBounds as String] as? [String: Any],
                  let cgX = bounds["X"] as? CGFloat,
                  let cgY = bounds["Y"] as? CGFloat,
                  let cgW = bounds["Width"] as? CGFloat,
                  let cgH = bounds["Height"] as? CGFloat else {
                continue
            }

            // 데스크톱 위젯(Layer < 0) 제외
            guard layer >= 0 else { continue }

            // 1. NotificationCenter 프로세스 소유의 배너 확인
            let isNotifProcess = bundleId == "com.apple.notificationcenterui"
                || owner.localizedCaseInsensitiveContains("notification")
                || owner.contains("알림")

            // 2. 상단 우측 알림 영역 (화면 우측 450pt 이내, 상단 450pt 이내)에 위치한 알림 창
            let inNotifCorner = (cgX >= screenFrame.maxX - 450) && (cgY <= 450) && (cgW >= 150 && cgH >= 40)

            if isNotifProcess && inNotifCorner {
                bannerCount += 1
            }
        }

        if bannerCount > 0 {
            if firstSeenBannerTime == nil {
                firstSeenBannerTime = now
            }
            let duration = now - (firstSeenBannerTime ?? now)

            // 알림이 2개 이상 쌓였거나, 1개라도 5.0초 이상 읽지 않고 방치된 경우 구박!
            let shouldNag = (bannerCount >= 2) || (duration >= 5.0)
            cachedStatus = NotificationNagStatus(
                shouldNag: shouldNag,
                bannerCount: bannerCount,
                lingeringDuration: duration
            )
        } else {
            firstSeenBannerTime = nil
            cachedStatus = NotificationNagStatus(shouldNag: false, bannerCount: 0, lingeringDuration: 0)
        }

        return cachedStatus
    }
}
