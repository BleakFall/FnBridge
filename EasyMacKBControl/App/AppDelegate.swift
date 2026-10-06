import AppKit
import OSLog

private let log = Logger(subsystem: "EasyMacKBControl", category: "AppDelegate")

/// 生命周期:启动即工作(不依赖窗口)、关窗不退出、重新打开找回设置。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppAppearance.apply(showInDock: Prefs.showInDock())
        MenuBarController.shared.updateVisibility()
        if !KeyMonitor.shared.start() {
            log.notice("事件钩子未启动(等授权);授权后可在设置里手动启动")
        }
    }

    /// 关闭最后一个窗口不退出 App(后台常驻的关键)。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 双隐藏(Dock+状态栏都关)后的找回通道:再次打开 App 即弹出设置窗口。
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .openSettings, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}
