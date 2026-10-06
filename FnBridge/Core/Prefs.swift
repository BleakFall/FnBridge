import Foundation

/// 全 App 共用的偏好键名与缺省值。唯一事实来源是 UserDefaults;
/// SwiftUI 侧用 @AppStorage,非 UI 侧用这里的读取函数,两边键名必须一致。
enum Prefs {
    static let enabledFKeyActions = "enabledFKeyActions"
    static let masterEnabled = "masterEnabled"
    static let showInDock = "showInDock"
    static let showInMenuBar = "showInMenuBar"

    /// 缺省 true(未写入视为开启)。
    static func masterEnabled(defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: masterEnabled) as? Bool) ?? true
    }

    /// 缺省 false。
    static func showInDock(defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: showInDock) as? Bool) ?? false
    }

    /// 缺省 true。
    static func showInMenuBar(defaults: UserDefaults = .standard) -> Bool {
        (defaults.object(forKey: showInMenuBar) as? Bool) ?? true
    }
}

extension Notification.Name {
    /// 请求打开设置窗口(Task 8 的 App 入口监听此通知)。
    static let openSettings = Notification.Name("FnBridge.openSettings")
}
