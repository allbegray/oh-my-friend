import Foundation
import IOKit.ps

public struct BatteryInfo {
    public let percent: Int
    public let isCharging: Bool
    public let hasBattery: Bool
}

/// 맥북 배터리 잔량 및 충전 상태를 모니터링하는 매니저
public final class BatteryStatusMonitor {
    public static let shared = BatteryStatusMonitor()

    public var isEnabled: Bool = true
    private var lastCheckTime: TimeInterval = 0
    private var cachedInfo = BatteryInfo(percent: 100, isCharging: true, hasBattery: false)

    private init() {}

    public func getBatteryInfo() -> BatteryInfo {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastCheckTime < 5.0 {
            return cachedInfo
        }
        lastCheckTime = now

        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return cachedInfo
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            let curCap = (desc[kIOPSCurrentCapacityKey] as? Int) ?? 100
            let maxCap = (desc[kIOPSMaxCapacityKey] as? Int) ?? 100
            let pct = maxCap > 0 ? Int((Double(curCap) / Double(maxCap)) * 100.0) : 100
            cachedInfo = BatteryInfo(percent: pct, isCharging: isCharging, hasBattery: true)
            return cachedInfo
        }

        return cachedInfo
    }
}
