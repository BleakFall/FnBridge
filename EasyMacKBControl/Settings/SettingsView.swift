import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gearshape") }
            KeyMappingTab()
                .tabItem { Label("按键映射", systemImage: "keyboard") }
            PermissionsTab()
                .tabItem { Label("权限与诊断", systemImage: "lock.shield") }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 640)
    }
}
