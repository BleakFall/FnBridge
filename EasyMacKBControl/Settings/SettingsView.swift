import SwiftUI

struct SettingsView: View {
    @ObservedObject private var router = SettingsRouter.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            KeyMappingTab()
                .tabItem { Label("按键映射", systemImage: "keyboard") }
                .tag(SettingsTab.keyMapping)
            PermissionsTab()
                .tabItem { Label("权限与诊断", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 640)
    }
}
