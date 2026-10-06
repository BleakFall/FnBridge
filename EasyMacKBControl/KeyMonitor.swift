import Cocoa
import OSLog

private let log = Logger(subsystem: "EasyMacKBControl", category: "KeyMonitor")

// MARK: - 系统事件发送

/// 系统定义事件中的“辅助控制键”码（即 IOKit 的 NX_KEYTYPE_* 常量）。
/// 发送这些事件的效果等价于按下妙控键盘上的专用键（亮度 / 音量 / 媒体）。
private enum AuxControlKey {
    static let soundUp: Int32 = 0
    static let soundDown: Int32 = 1
    static let brightnessUp: Int32 = 2
    static let brightnessDown: Int32 = 3
    static let mute: Int32 = 7
    static let play: Int32 = 16
    static let next: Int32 = 17
    static let previous: Int32 = 18
    static let fast: Int32 = 19
    static let rewind: Int32 = 20
}

/// 发送一个系统定义“辅助控制键”（按下 + 抬起）。
/// 需要“辅助功能”权限（否则 post 到 HID 会被系统忽略）。
private func postAuxKey(_ key: Int32) {
    postAuxKeyEvent(key, down: true)
    postAuxKeyEvent(key, down: false)
}

private func postAuxKeyEvent(_ key: Int32, down: Bool) {
    // data1 = (keyCode << 16) | (0xA00 按下 / 0xB00 抬起)
    let data1 = Int(key) << 16 | (down ? 0xA00 : 0xB00)
    let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
    guard let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: flags,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,            // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        data1: data1,
        data2: -1
    ) else {
        log.error("构造系统定义事件失败")
        return
    }
    event.cgEvent?.post(tap: .cghidEventTap)
}

/// 发送 ⌘+空格 唤起聚焦搜索（Spotlight）。F4 的等价操作。
private func postSpotlight() {
    let source = CGEventSource(stateID: .hidSystemState)
    let space: CGKeyCode = 49   // kVK_Space
    let down = CGEvent(keyboardEventSource: source, virtualKey: space, keyDown: true)
    down?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: source, virtualKey: space, keyDown: false)
    up?.flags = .maskCommand
    up?.post(tap: .cghidEventTap)
}

// MARK: - 监听器

/// 全局事件钩子：把“标准 F 键码”转换成 macOS 系统功能。
///
/// 原理：
/// - 苹果原装键盘的 F 区专用功能发的是系统私有 HID usage，不经过这里（不受影响）。
/// - 外接键盘（如 HHKB 的 Fn+数字）发的是标准 F 键码，这里拦截并转成对应系统功能。
final class KeyMonitor {
    static let shared = KeyMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    // 诊断信息（供 UI 轮询显示）
    private(set) var lastKeyCode: Int64 = -1
    private(set) var lastTriggerDate: Date?
    private(set) var lastAction: FKeyAction?

    // 防止按住不放时重复触发过于密集，保留一个小节流。
    private var lastFire: TimeInterval = 0
    private let debounce: TimeInterval = 0.12

    // MARK: 启停

    /// 启动监听。失败（通常是没授予“输入监控”权限）返回 false。
    @discardableResult
    func start() -> Bool {
        if isRunning { return true }

        log.info("start: inputMonitoring=\(CGPreflightListenEventAccess()) postingAccess=\(CGPreflightPostEventAccess())")

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyMonitorTapCallback,
            userInfo: nil
        ) else {
            log.error("tapCreate 失败：通常是没有“输入监控”权限")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        eventTap = tap
        runLoopSource = source
        isRunning = true
        log.info("事件钩子已启动")
        return true
    }

    func stop() {
        guard isRunning else { return }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
        log.info("事件钩子已停止")
    }

    // MARK: 启用状态（存取已抽取到 Core/FKeySettings.swift）

    /// 根据键码找到“已启用”的动作；未启用或非 F 键返回 nil。
    private func action(forKeyCode keyCode: CGKeyCode) -> FKeyAction? {
        guard let action = FKeyAction.allCases.first(where: { $0.keyCode == keyCode }) else {
            return nil
        }
        return FKeySettings().enabled.contains(action) ? action : nil
    }

    // MARK: 事件回调（在主 RunLoop 线程）

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            lastKeyCode = keyCode
        }

        guard keyCode >= 0 else {
            return Unmanaged.passUnretained(event)
        }

        guard let action = action(forKeyCode: CGKeyCode(keyCode)) else {
            return Unmanaged.passUnretained(event)
        }

        // 命中已启用的 F 键：吞掉，不让它进入任何 App。
        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat || action.isRepeatable {
                lastTriggerDate = Date()
                lastAction = action
                log.info("检测到 \(action.keyLabel)(键码 \(keyCode))，执行 \(action.rawValue)")
                fire(action)
            }
        }
        return nil
    }

    private func fire(_ action: FKeyAction) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFire > debounce else { return }
        lastFire = now
        DispatchQueue.main.async {
            Self.perform(action)
        }
    }

    private static func perform(_ action: FKeyAction) {
        switch action {
        case .brightnessDown: postAuxKey(AuxControlKey.brightnessDown)
        case .brightnessUp:   postAuxKey(AuxControlKey.brightnessUp)
        case .missionControl: postMissionControl()
        case .spotlight:      postSpotlight()
        case .previousTrack:  postAuxKey(AuxControlKey.previous)
        case .playPause:      postAuxKey(AuxControlKey.play)
        case .nextTrack:      postAuxKey(AuxControlKey.next)
        case .mute:           postAuxKey(AuxControlKey.mute)
        case .volumeDown:     postAuxKey(AuxControlKey.soundDown)
        case .volumeUp:       postAuxKey(AuxControlKey.soundUp)
        case .dictation, .focus:
            log.notice("动作 \(action.rawValue) 暂无公开接口，忽略")
        }
    }

    /// 唤起调度中心。
    ///
    /// 启动系统自带的 launcher `/System/Applications/Mission Control.app`
    /// （bundle id: com.apple.exposelauncher）。它内部调用私有
    /// `CoreDockSendNotification("com.apple.expose.awake", 0)` 让 Dock 切换调度中心，
    /// 与苹果键盘 F3 走同一通道。
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

/// 必须用顶层函数传给 C 回调（不能是带捕获上下文的闭包）。
private func keyMonitorTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    return KeyMonitor.shared.handle(type: type, event: event)
}
