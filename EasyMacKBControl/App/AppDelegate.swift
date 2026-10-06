import AppKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "EasyMacKBControl", category: "AppDelegate")

/// 生命周期:启动即工作(不依赖窗口)、关窗不退出、重新打开找回设置。
///
/// v2 修复(评审 #1):设置窗口由 AppDelegate 持久持有(NSWindow),而非依赖
/// SwiftUI WindowGroup + 已关闭窗口的 onReceive 观察者。这样"双隐藏后重新打开
/// App"时,`applicationShouldHandleReopen` 直接 `makeKeyAndOrderFront`,不依赖任何
/// 可能已销毁的视图。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 持久持有的设置窗口(关闭后复用,见 isReleasedWhenClosed=false)。
    private(set) var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppAppearance.apply(showInDock: Prefs.showInDock())
        MenuBarController.shared.updateVisibility()
        if !KeyMonitor.shared.start() {
            log.notice("事件钩子未启动(等授权);授权后可在设置里手动启动")
        }

        // 菜单栏"打开设置…"发 .openSettings 通知;AppDelegate 持久监听(始终活着)。
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
        showSettings()
    }

    /// 关闭最后一个窗口不退出 App(后台常驻的关键)。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 双隐藏(Dock+状态栏都关)后的找回通道:再次打开 App 即弹出设置窗口。
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func handleOpenSettings() {
        showSettings()
    }

    /// 创建或复用设置窗口并置前。幂等:重复调用复用同一窗口,不产生副本。
    @objc func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false  // 关窗后对象仍存活,可复用
        window.title = "EasyMacKBControl"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
