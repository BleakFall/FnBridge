import Cocoa
import OSLog

private let log = Logger(subsystem: "EasyMacKBControl", category: "KeyMonitor")

// macOS 虚拟键码（即 Carbon 的 kVK_* 常量值）
extension CGKeyCode {
    /// F3 = 0x63（苹果键盘默认用它唤起调度中心）
    static let f3: CGKeyCode = 99
    /// F5 = 0x60（VSCode 默认用它 debug，若改用它会占用该键）
    static let f5: CGKeyCode = 96
}

/// 全局事件钩子：把“标准 F 键码”转成 macOS 系统功能。
///
/// 原理：
/// - 苹果原装键盘的 F3 发的是系统私有 HID usage，不经过这里（不受影响）。
/// - HHKB 的 Fn+3 发的是标准 F3 键码，这里拦截并转成调度中心。
final class KeyMonitor {
    static let shared = KeyMonitor()

    /// 触发键。默认 F3；想用 F5 就改成 `.f5`（注意会占用 VSCode 的 debug 键）。
    var triggerKey: CGKeyCode = .f3

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    // 诊断信息（供 UI 轮询显示）
    private(set) var lastKeyCode: Int64 = -1
    private(set) var lastTriggerDate: Date?

    // 防止按住不放时自动重复触发，只认第一次按下。
    private var lastFire: TimeInterval = 0
    private let debounce: TimeInterval = 0.15

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

    // 在事件钩子回调里调用（主 RunLoop 线程）
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            lastKeyCode = keyCode
        }

        guard keyCode == Int64(triggerKey) else {
            return Unmanaged.passUnretained(event)
        }

        // 命中触发键：吞掉，不让它进入任何 App。
        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat {
                lastTriggerDate = Date()
                log.info("检测到触发键(键码 \(keyCode))，发送调度中心")
                fire()
            }
        }
        return nil
    }

    private func fire() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFire > debounce else { return }
        lastFire = now
        DispatchQueue.main.async {
            Self.postMissionControl()
        }
    }

    /// 唤起调度中心。
    ///
    /// 启动系统自带的 launcher `/System/Applications/Mission Control.app`
    /// （bundle id: com.apple.exposelauncher）。它内部调用私有
    /// `CoreDockSendNotification("com.apple.expose.awake", 0)` 让 Dock 切换调度中心，
    /// 与苹果键盘 F3 走同一通道。
    /// 合成按键(Control+↑)与分布式通知都无法触发，因为调度中心的符号热键
    /// 在 HID/私有层匹配，普通 App 够不到。
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
