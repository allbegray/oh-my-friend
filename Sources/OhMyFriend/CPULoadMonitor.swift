import Foundation
import Darwin

/// 시스템 전체 CPU 사용률을 Mach host_processor_info로 샘플링하는 모니터
public final class CPULoadMonitor {
    public static let shared = CPULoadMonitor()

    public var isEnabled: Bool = true
    private var lastCheckTime: TimeInterval = 0
    private var cachedValue: Double = 0.0
    private var prevIdle: UInt64 = 0
    private var prevTotal: UInt64 = 0
    private var hasBaseline: Bool = false

    private init() {}

    public func cpuPercent() -> Double {
        guard isEnabled else { return cachedValue }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastCheckTime < 5.0 {
            return cachedValue
        }
        lastCheckTime = now

        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t? = nil
        var cpuInfoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return cachedValue
        }
        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }
        guard cpuCount > 0 else { return cachedValue }

        var idle: UInt64 = 0
        var total: UInt64 = 0
        info.withMemoryRebound(to: processor_cpu_load_info_data_t.self, capacity: Int(cpuCount)) { ptr in
            for i in 0..<Int(cpuCount) {
                let ticks = ptr[i].cpu_ticks
                let user = UInt64(ticks.0)
                let system = UInt64(ticks.1)
                let idleTicks = UInt64(ticks.2)
                let nice = UInt64(ticks.3)
                idle += idleTicks
                total += user + system + idleTicks + nice
            }
        }

        guard hasBaseline else {
            prevIdle = idle
            prevTotal = total
            hasBaseline = true
            return cachedValue
        }

        let totalDiff = total >= prevTotal ? total - prevTotal : 0
        let idleDiff = idle >= prevIdle ? idle - prevIdle : 0
        prevIdle = idle
        prevTotal = total
        guard totalDiff > 0 else { return cachedValue }

        let usage = (1.0 - Double(idleDiff) / Double(totalDiff)) * 100.0
        cachedValue = min(100.0, max(0.0, usage))
        return cachedValue
    }
}
