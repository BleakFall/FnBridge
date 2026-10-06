import SwiftUI

/// 设置窗口容器:顶部一条页签条,下方是选中页的内容。
///
/// 页签不用 `TabView`——macOS 上默认样式的 `TabView` 会把页签提升到窗口标题栏
/// 区域(渲染在红绿灯按钮右侧)。改用内容区里的 segmented `Picker`,页签就落在
/// 标题栏下方,和窗口内容一起排版。
struct SettingsView: View {
    @ObservedObject private var router = SettingsRouter.shared

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            content
                .padding(20)
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    /// 页签条:绑定的仍是 SettingsRouter,菜单栏跳页等外部切换照常生效。
    private var tabPicker: some View {
        Picker("", selection: $router.selectedTab) {
            Label("通用", systemImage: "gearshape")
                .tag(SettingsTab.general)
            Label("按键映射", systemImage: "keyboard")
                .tag(SettingsTab.keyMapping)
            Label("权限与诊断", systemImage: "lock.shield")
                .tag(SettingsTab.permissions)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch router.selectedTab {
        case .general: GeneralTab()
        case .keyMapping: KeyMappingTab()
        case .permissions: PermissionsTab()
        }
    }
}
