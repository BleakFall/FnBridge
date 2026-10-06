import AppKit
import OSLog

private let log = Logger(subsystem: "EasyMacKBControl", category: "MenuBar")

/// 状态栏图标与菜单。菜单在每次展开时重建(menuNeedsUpdate),保证权限/开关状态实时。
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?

    /// 菜单状态行标题(纯函数,locale 可注入以测试本地化)。
    static func statusLineTitle(canListen: Bool, canPost: Bool,
                                monitoring: Bool, locale: Locale) -> String {
        if canListen && canPost && monitoring {
            return String(localized: String.LocalizationValue("✓ 运行中"), bundle: .main, locale: locale)
        } else if !canListen || !canPost {
            return String(localized: String.LocalizationValue("⚠️ 缺少权限,点击前往系统设置"), bundle: .main, locale: locale)
        } else {
            return String(localized: String.LocalizationValue("⚠️ 监听未启动"), bundle: .main, locale: locale)
        }
    }

    /// 依据 Prefs.showInMenuBar 创建或移除状态栏项。
    /// 由启动流程(Task 8)与设置界面(Task 9)在开关变化时调用。
    func updateVisibility() {
        let show = Prefs.showInMenuBar()
        if show, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(named: "StatusBarIcon")
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if !show, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - 菜单动作(目标动作必须在 NSObject 上)

    @objc private func toggleMaster(_ sender: NSMenuItem) {
        let on = !Prefs.masterEnabled()
        UserDefaults.standard.set(on, forKey: Prefs.masterEnabled)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            try LaunchAtLogin.setEnabled(sender.state != .on)
        } catch {
            log.error("切换开机自启失败: \(error.localizedDescription)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openPrivacySettings() {
        // 输入监控面板
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension MenuBarController: NSMenuDelegate {
    /// 每次展开时重建,状态永远新鲜。
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let canListen = CGPreflightListenEventAccess()
        let canPost = CGPreflightPostEventAccess()
        let monitoring = KeyMonitor.shared.isRunning

        let statusLine: NSMenuItem
        let statusTitle = Self.statusLineTitle(canListen: canListen, canPost: canPost,
                                               monitoring: monitoring, locale: .current)
        if canListen && canPost && monitoring {
            statusLine = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        } else if !canListen || !canPost {
            statusLine = NSMenuItem(title: statusTitle, action: #selector(openPrivacySettings), keyEquivalent: "")
        } else {
            statusLine = NSMenuItem(title: statusTitle, action: #selector(openSettings), keyEquivalent: "")
        }
        menu.addItem(statusLine)
        menu.addItem(.separator())

        let master = NSMenuItem(title: String(localized: "启用 F 键转换"),
                                action: #selector(toggleMaster(_:)),
                                keyEquivalent: "")
        master.target = self
        master.state = Prefs.masterEnabled() ? .on : .off
        menu.addItem(master)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: String(localized: "打开设置…"),
                                  action: #selector(openSettings),
                                  keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: String(localized: "开机自启"),
                               action: #selector(toggleLaunchAtLogin(_:)),
                               keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "退出 EasyMacKBControl"),
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
}
