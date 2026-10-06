import Foundation

/// F 键启用状态的存取层。纯逻辑,注入 UserDefaults 以便单元测试。
struct FKeySettings {
    var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabled: Set<FKeyAction> {
        get {
            guard let raw = defaults.stringArray(forKey: Prefs.enabledFKeyActions) else {
                return FKeyAction.defaultEnabled
            }
            return Set(raw.compactMap { FKeyAction(rawValue: $0) })
        }
        set {
            defaults.set(newValue.map { $0.rawValue }.sorted(),
                         forKey: Prefs.enabledFKeyActions)
        }
    }

    /// 全局总开关。缺省 true。KeyMonitor 通过注入的 defaults 读取(可测)。
    var masterEnabled: Bool {
        get { (defaults.object(forKey: Prefs.masterEnabled) as? Bool) ?? true }
        set { defaults.set(newValue, forKey: Prefs.masterEnabled) }
    }

    /// 死键防护:不支持的键(F5/F6)永远不拦截,即使残留启用状态。
    func isInterceptable(_ action: FKeyAction) -> Bool {
        action.supported && enabled.contains(action)
    }

    /// mutating 是刻意的:@State 包装下的 mutating 调用会触发 SwiftUI 刷新。
    mutating func setEnabled(_ action: FKeyAction, _ on: Bool) {
        var set = enabled
        if on { set.insert(action) } else { set.remove(action) }
        enabled = set
    }

    mutating func resetToDefaults() {
        defaults.removeObject(forKey: Prefs.enabledFKeyActions)
    }
}
