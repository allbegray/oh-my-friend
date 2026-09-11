import AppKit
import CoreGraphics

// 전 엔티티 패널의 공용 베이스: 투명 무테 플로팅 패널 상용구를 한 곳에 응축.
// 서브클래스는 super.init 한 줄로 설정이 끝나며, 그리기·타이머·상호작용만 각자 가진다.
public class EntityWindow: NSPanel {
    public init(
        contentRect: NSRect,
        ignoresMouse: Bool = false,
        level: NSWindow.Level = .floating
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = ignoresMouse
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    public var autoDismissDuration: TimeInterval = 12.0
    private var autoDismissTimer: Timer?

    public func scheduleAutoDismiss(after duration: TimeInterval = 12.0, onDismiss: (() -> Void)? = nil) {
        autoDismissTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            onDismiss?()
            self.close()
        }
        RunLoop.main.add(t, forMode: .common)
        self.autoDismissTimer = t
    }

    open override func orderFrontRegardless() {
        super.orderFrontRegardless()
        if autoDismissDuration > 0 && autoDismissTimer == nil {
            scheduleAutoDismiss(after: autoDismissDuration)
        }
    }

    open override func close() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        super.close()
    }
}
