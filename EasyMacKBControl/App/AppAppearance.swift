import AppKit

/// Dock 显示形态切换。LSUIElement=YES 使 App 以 accessory 启动;
/// 用户选择“在程序坞显示”时运行时升级为 regular。
enum AppAppearance {
    static func activationPolicy(showInDock: Bool) -> NSApplication.ActivationPolicy {
        showInDock ? .regular : .accessory
    }

    static func apply(showInDock: Bool) {
        NSApp.setActivationPolicy(activationPolicy(showInDock: showInDock))
    }
}
