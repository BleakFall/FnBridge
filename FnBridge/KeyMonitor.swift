import Cocoa
import OSLog

private let log = Logger(subsystem: "FnBridge", category: "KeyMonitor")

// MARK: - 监听器

/// 全局事件钩子：把“标准 F 键码”转换成 macOS 系统功能。
///
/// 原理：
/// - 苹果原装键盘的 F 区专用功能发的是系统私有 HID usage，不经过这里（不受影响）。
/// - 外接键盘（如 HHKB 的 Fn+数字）发的是标准 F 键码，这里拦截并转成对应系统功能。
///
/// 可靠性设计(v2)：
/// - tap 被系统超时禁用时自动重新启用（自愈），不再静默失效。
/// - 权限被吊销（tapDisabledByUserInput）时如实置为未运行，供 UI 提示。
/// - 节流按键独立：快速连按不同 F 键互不影响。
/// - 总开关（masterEnabled）关闭时放行所有键。
final class KeyMonitor {
    static let shared = KeyMonitor()

    private let settings: FKeySettings
    private let performer: (FKeyAction) -> Void
    private let clock: () -> TimeInterval
    private let dispatch: (@escaping () -> Void) -> Void

    /// 每键独立的最近触发时间（v2：取代全局单一 lastFire）。
    private var lastFireByKey: [FKeyAction: TimeInterval] = [:]
    private let debounce: TimeInterval = 0.12

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isRunning = false

    // 诊断信息（供 UI 轮询显示）
    private(set) var lastKeyCode: Int64 = -1
    private(set) var lastTriggerDate: Date?
    private(set) var lastAction: FKeyAction?

    init(
        settings: FKeySettings = FKeySettings(),
        performer: @escaping (FKeyAction) -> Void = SystemEventPoster.post,
        clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        dispatch: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.settings = settings
        self.performer = performer
        self.clock = clock
        self.dispatch = dispatch
    }

    // MARK: 启停

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

    /// 仅供测试：绕过权限直接置为运行态。
    func startIfPossibleForTesting() {
        isRunning = true
    }

    // MARK: 事件处理（在主 RunLoop 线程）

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // v2 自愈：系统因回调超时禁用 tap 时，立即重新启用。
        if type == .tapDisabledByTimeout {
            if let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                log.notice("事件钩子被系统超时禁用，已自动重新启用")
            }
            return Unmanaged.passUnretained(event)
        }
        // v2：权限被吊销 → 如实置为未运行（UI 会显示并可引导重新授权）。
        if type == .tapDisabledByUserInput {
            stop()
            log.error("事件钩子被系统禁用（权限变动），已停止监听")
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown {
            lastKeyCode = keyCode
        }
        guard keyCode >= 0 else {
            return Unmanaged.passUnretained(event)
        }

        // v2 总开关：关闭时放行所有键（读注入的 defaults，保证可测）。
        guard settings.masterEnabled else {
            return Unmanaged.passUnretained(event)
        }

        guard let action = FKeyAction.allCases.first(where: { $0.keyCode == keyCode }),
              settings.isInterceptable(action) else {
            return Unmanaged.passUnretained(event)
        }

        // 命中已启用的 F 键：吞掉，不让它进入任何 App。
        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat || action.isRepeatable {
                if shouldFire(action) {
                    lastTriggerDate = Date()
                    lastAction = action
                    log.info("检测到 \(action.keyLabel)(键码 \(keyCode))，执行 \(action.rawValue)")
                    fire(action)
                }
            }
        }
        return nil
    }

    /// v2：节流按键独立，只压制同一键的密集重复。
    private func shouldFire(_ action: FKeyAction) -> Bool {
        let now = clock()
        if let last = lastFireByKey[action], now - last <= debounce {
            return false
        }
        lastFireByKey[action] = now
        return true
    }

    private func fire(_ action: FKeyAction) {
        dispatch { [performer] in
            performer(action)
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
