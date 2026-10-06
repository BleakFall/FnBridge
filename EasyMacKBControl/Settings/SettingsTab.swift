import Combine

/// 设置窗口的三个页签。
enum SettingsTab: Hashable {
    case general
    case keyMapping
    case permissions
}

/// 跨模块共享的页签选择状态：菜单栏“打开设置…”与 AppDelegate 都能切换。
final class SettingsRouter: ObservableObject {
    static let shared = SettingsRouter()
    @Published var selectedTab: SettingsTab = .general
}
