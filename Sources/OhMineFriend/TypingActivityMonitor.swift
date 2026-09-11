import AppKit
import Foundation

/// 키보드 타이핑 속도(WPM / KPM)를 실시간으로 감지하고 관리하는 싱글톤
public final class TypingActivityMonitor {
    public static let shared = TypingActivityMonitor()

    public var isEnabled: Bool = true {
        didSet {
            if !isEnabled {
                keystrokeTimestamps.removeAll()
            }
        }
    }

    /// 타 앱의 타이핑 감지를 위한 macOS 손쉬운 사용(Accessibility) 권한 부여 여부
    public var isAccessibilityTrusted: Bool {
        return AXIsProcessTrusted()
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keystrokeTimestamps: [TimeInterval] = []
    private let queue = DispatchQueue(label: "com.hong.ohminefriend.typing", qos: .userInteractive)

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        guard globalMonitor == nil && localMonitor == nil else { return }

        // 1. Global monitor: macOS 타 앱(Xcode, 브라우저, 터미널 등)에서 타이핑 감지 (손쉬운 사용 권한 시 동작)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            self?.recordKeystroke()
        }

        // 2. Local monitor: 자체 앱 활성화 중 타이핑 감지
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.recordKeystroke()
            return event
        }
    }

    public func stopMonitoring() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }

    public func recordKeystroke() {
        guard isEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        queue.async {
            self.keystrokeTimestamps.append(now)
            self.cleanOldTimestamps(now: now)
        }
    }

    /// 테스트 또는 강제 응원 트리거용 시뮬레이션 메서드
    public func simulateKeystrokes(count: Int = 12) {
        let now = ProcessInfo.processInfo.systemUptime
        queue.async {
            for i in 0..<count {
                self.keystrokeTimestamps.append(now - Double(i) * 0.1)
            }
            self.cleanOldTimestamps(now: now)
        }
    }

    /// 최근 4초간의 타수를 바탕으로 분당 단어 수 (Words Per Minute, 1단어=5타수) 계산
    public var currentWPM: Double {
        guard isEnabled else { return 0 }
        var result: Double = 0
        queue.sync {
            let now = ProcessInfo.processInfo.systemUptime
            cleanOldTimestamps(now: now)
            guard keystrokeTimestamps.count >= 3 else {
                result = 0
                return
            }
            // 4초 윈도우 기준 분당 타수(KPM) 환산 (60 / 4.0 = 15.0)
            let kpm = Double(keystrokeTimestamps.count) * 15.0
            result = kpm / 5.0 // WPM
        }
        return result
    }

    private func cleanOldTimestamps(now: TimeInterval) {
        let cutoff = now - 4.0
        keystrokeTimestamps.removeAll { $0 < cutoff }
    }
}
