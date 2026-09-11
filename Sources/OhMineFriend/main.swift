import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 옛 이름(Oh My Friend)의 설정·스킨 보관함을 먼저 옮긴다.
        // AppController 가 밝기·날씨·발전 과제 기본값을 읽기 전에 끝나야 한다.
        LegacyMigration.runIfNeeded()
        controller = AppController()
        controller?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
