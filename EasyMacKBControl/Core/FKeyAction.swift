import CoreGraphics
import Foundation

// MARK: - F 区功能定义

/// 原生妙控键盘 F 区（F1–F12）对应的系统功能。
///
/// 注意：苹果原装键盘的 F 区在“不按 Fn”时发出的是系统私有 HID usage（不经过事件流），
/// 本 App 无法也不应拦截；本 App 处理的是外接键盘（如 HHKB 的 Fn+数字）发出的
/// **标准 F 键码**，把它们转换成等价的系统功能。
enum FKeyAction: String, CaseIterable, Identifiable {
    case brightnessDown  // F1
    case brightnessUp    // F2
    case missionControl  // F3
    case spotlight       // F4
    case dictation       // F5
    case focus           // F6
    case previousTrack   // F7
    case playPause       // F8
    case nextTrack       // F9
    case mute            // F10
    case volumeDown      // F11
    case volumeUp        // F12

    var id: String { rawValue }

    /// 对应的 macOS 虚拟键码（Carbon kVK_* 常量值）。
    var keyCode: CGKeyCode {
        switch self {
        case .brightnessDown: return 122   // kVK_F1
        case .brightnessUp:   return 120   // kVK_F2
        case .missionControl: return 99    // kVK_F3
        case .spotlight:      return 118   // kVK_F4
        case .dictation:      return 96    // kVK_F5
        case .focus:          return 97    // kVK_F6
        case .previousTrack:  return 98    // kVK_F7
        case .playPause:      return 100   // kVK_F8
        case .nextTrack:      return 101   // kVK_F9
        case .mute:           return 109   // kVK_F10
        case .volumeDown:     return 103   // kVK_F11
        case .volumeUp:       return 111   // kVK_F12
        }
    }

    /// 键名（如 "F1"）。
    var keyLabel: String {
        switch self {
        case .brightnessDown: return "F1"
        case .brightnessUp:   return "F2"
        case .missionControl: return "F3"
        case .spotlight:      return "F4"
        case .dictation:      return "F5"
        case .focus:          return "F6"
        case .previousTrack:  return "F7"
        case .playPause:      return "F8"
        case .nextTrack:      return "F9"
        case .mute:           return "F10"
        case .volumeDown:     return "F11"
        case .volumeUp:       return "F12"
        }
    }

    /// 功能描述（本地化：跟随系统语言，英文翻译见 Localizable.xcstrings）。
    var title: String {
        String(localized: String.LocalizationValue(titleKey), bundle: .main)
    }

    /// 本地化键（源语言为简体中文）。internal 供测试验证英文翻译齐全。
    var titleKey: String {
        switch self {
        case .brightnessDown: return "降低屏幕亮度"
        case .brightnessUp:   return "提高屏幕亮度"
        case .missionControl: return "调度中心（Mission Control）"
        case .spotlight:      return "聚焦搜索（Spotlight）"
        case .dictation:      return "听写"
        case .focus:          return "专注模式 / 勿扰"
        case .previousTrack:  return "上一曲"
        case .playPause:      return "播放 / 暂停"
        case .nextTrack:      return "下一曲"
        case .mute:           return "静音"
        case .volumeDown:     return "降低音量"
        case .volumeUp:       return "提高音量"
        }
    }

    /// 该功能当前能否可靠触发。
    /// 听写 / 专注模式 macOS 没有公开的编程接口，暂不支持（保持普通 F 键）。
    var supported: Bool {
        self != .dictation && self != .focus
    }

    /// 按住不放时是否允许自动重复触发（亮度 / 音量 / 媒体键适合重复）。
    var isRepeatable: Bool {
        switch self {
        case .brightnessDown, .brightnessUp,
             .previousTrack, .playPause, .nextTrack,
             .mute, .volumeDown, .volumeUp:
            return true
        default:
            return false
        }
    }

    /// 默认启用的动作（排除暂不支持的听写 / 专注）。
    static var defaultEnabled: Set<FKeyAction> {
        Set(allCases.filter { $0.supported })
    }
}
