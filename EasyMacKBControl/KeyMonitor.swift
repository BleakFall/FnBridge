import Cocoa
import OSLog

private let log = Logger(subsystem: "EasyMacKBControl", category: "KeyMonitor")

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
        SystemEventPoster.post(action)
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
