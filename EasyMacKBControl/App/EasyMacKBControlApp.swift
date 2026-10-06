import SwiftUI

@main
struct EasyMacKBControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "settings") {
            SettingsView()
                .openSettingsOnNotification()
        }
        .windowResizability(.contentSize)
    }
}

/// 监听 .openSettings 通知(菜单栏/重新打开触发)并打开设置窗口。
private struct OpenSettingsListener: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openWindow(id: "settings")
        }
    }
}

extension View {
    func openSettingsOnNotification() -> some View {
        modifier(OpenSettingsListener())
    }
}
