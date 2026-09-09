import AppKit
import SwiftUI

public final class SkinGalleryWindowController: NSWindowController {
    public static let shared = SkinGalleryWindowController()

    private var onApplySkinHandler: ((SkinTexture, String) -> Void)?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "마인크래프트 스킨 갤러리 & 다운로더"
        window.center()
        window.setFrameAutosaveName("OhMyFriend_SkinGalleryWindow")
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show(onApply: @escaping (SkinTexture, String) -> Void) {
        self.onApplySkinHandler = onApply

        let view = SkinGalleryView { [weak self] skin, name in
            self?.onApplySkinHandler?(skin, name)
        }
        window?.contentView = NSHostingView(rootView: view)

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
