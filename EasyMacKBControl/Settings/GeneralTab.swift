import SwiftUI

struct GeneralTab: View {
    @AppStorage(Prefs.masterEnabled) private var masterEnabled = true
    @AppStorage(Prefs.showInDock) private var showInDock = false
    @AppStorage(Prefs.showInMenuBar) private var showInMenuBar = true
    @State private var confirmHideAll = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                Toggle("启用 F 键转换", isOn: $masterEnabled)
            } header: {
                Text("功能")
            } footer: {
                Text("关闭后所有按键原样放行,不再拦截任何 F 键")
            }

            Section {
                Toggle("开机自启", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do { try LaunchAtLogin.setEnabled(on) }
                        catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                Toggle("在程序坞显示", isOn: $showInDock)
                    .onChange(of: showInDock) { on in
                        AppAppearance.apply(showInDock: on)
                    }
                Toggle("在状态栏显示图标", isOn: $showInMenuBar)
                    .onChange(of: showInMenuBar) { on in
                        MenuBarController.shared.updateVisibility()
                        if !on && !showInDock { confirmHideAll = true }
                    }
            } header: {
                Text("界面")
            } footer: {
                if let launchError {
                    Text("开机自启设置失败:\(launchError)")
                        .foregroundStyle(.orange)
                } else {
                    Text("两者都关闭后,在启动台或访达中重新打开本 App 可找回设置")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .confirmationDialog("同时隐藏程序坞与状态栏?",
                            isPresented: $confirmHideAll,
                            titleVisibility: .visible) {
            Button("仍然隐藏") { /* 状态已写入,无需回滚 */ }
            Button("取消", role: .cancel) {
                showInMenuBar = true
                MenuBarController.shared.updateVisibility()
            }
        } message: {
            Text("App 将不可见,但仍在后台工作;在启动台或访达重新打开本 App 可找回")
        }
    }
}
