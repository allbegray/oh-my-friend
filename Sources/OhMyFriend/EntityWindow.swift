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
}
