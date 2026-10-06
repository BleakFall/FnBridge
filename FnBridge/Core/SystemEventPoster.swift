import Cocoa
import OSLog

private let log = Logger(subsystem: "FnBridge", category: "SystemEventPoster")

/// 系统事件发送层:把 FKeyAction 转成等价的系统功能。
/// 发送副作用集中在此,纯数据(auxEventData1 / auxKeyByAction)可单测。
enum SystemEventPoster {
    /// FKeyAction → NX_KEYTYPE_*(IOKit hidsystem 常量值)。
    static let auxKeyByAction: [FKeyAction: Int32] = [
        .volumeUp: 0, .volumeDown: 1,
        .brightnessUp: 2, .brightnessDown: 3,
        .mute: 7,
        .playPause: 16, .nextTrack: 17, .previousTrack: 18,
    ]

    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS 的 data1 编码(纯函数,可单测)。
    static func auxEventData1(key: Int32, down: Bool) -> Int {
        Int(key) << 16 | (down ? 0xA00 : 0xB00)
    }

    /// 发送一个动作(按下+抬起)。Task 5 的默认执行器。
    static func post(_ action: FKeyAction) {
        switch action {
        case .missionControl:
            postMissionControl()
        case .spotlight:
            postSpotlight()
        case .dictation, .focus:
            log.notice("动作 \(action.rawValue) 暂无公开接口,忽略")
        default:
            guard let key = auxKeyByAction[action] else {
                log.error("动作 \(action.rawValue) 没有对应的 NX 键值")
                return
            }
            postAuxKeyEvent(key, down: true)
            postAuxKeyEvent(key, down: false)
        }
    }

    // MARK: - 以下为私有实现(从原 KeyMonitor.swift 原样搬移)

    private static func postAuxKeyEvent(_ key: Int32, down: Bool) {
        let data1 = auxEventData1(key: key, down: down)
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1, data2: -1
        ) else {
            log.error("构造系统定义事件失败")
            return
        }
        event.cgEvent?.post(tap: .cghidEventTap)
    }

    private static func postSpotlight() {
        let source = CGEventSource(stateID: .hidSystemState)
        let space: CGKeyCode = 49
        let down = CGEvent(keyboardEventSource: source, virtualKey: space, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: space, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    private static func postMissionControl() {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error {
                log.error("启动 Mission Control.app 失败: \(error.localizedDescription)")
            } else {
                log.info("已通过系统 Mission Control.app 唤起调度中心")
            }
        }
    }
}
