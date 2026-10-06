import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import FnBridge

final class KeyMonitorTests: XCTestCase {
    private var suite: UserDefaults!
    private var recorded: [FKeyAction] = []
    /// 固定时钟,测试里手动推进。
    private var now: TimeInterval = 1000
    private var monitor: KeyMonitor!

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: "KeyMonitorTests")
        suite.removePersistentDomain(forName: "KeyMonitorTests")
        recorded = []
        now = 1000
        monitor = KeyMonitor(
            settings: FKeySettings(defaults: suite),
            performer: { [weak self] in self?.recorded.append($0) },
            clock: { [weak self] in self?.now ?? 0 },
            dispatch: { $0() }   // 测试中同步执行
        )
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: "KeyMonitorTests")
        suite = nil
        monitor = nil
        super.tearDown()
    }

    private func keyEvent(_ code: CGKeyCode, isRepeat: Bool = false) -> CGEvent {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
        if isRepeat { e.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        return e
    }

    func testEnabledKeyIsSwallowedAndPerformed() {
        monitor.handle(type: .keyDown, event: keyEvent(99)) // F3 missionControl
        XCTAssertEqual(recorded, [.missionControl])
    }

    func testUnsupportedKeysAreNeverIntercepted() {
        // 模拟旧版本残留:F5/F6 被写入启用集合
        var set = FKeyAction.defaultEnabled
        set.insert(.dictation); set.insert(.focus)
        suite.set(set.map(\.rawValue), forKey: Prefs.enabledFKeyActions)

        for code in [CGKeyCode(96), CGKeyCode(97)] { // F5/F6
            XCTAssertTrue(monitor.handle(type: .keyDown, event: keyEvent(code)) != nil,
                          "不支持的键必须原样放行(死键防护)")
        }
        XCTAssertTrue(recorded.isEmpty)
    }

    func testDisabledKeyPassesThrough() {
        suite.set([String](), forKey: Prefs.enabledFKeyActions) // 全部关闭
        XCTAssertTrue(monitor.handle(type: .keyDown, event: keyEvent(99)) != nil)
        XCTAssertTrue(recorded.isEmpty)
    }

    func testMasterOffPassesEverything() {
        suite.set(false, forKey: Prefs.masterEnabled)
        XCTAssertTrue(monitor.handle(type: .keyDown, event: keyEvent(99)) != nil)
        XCTAssertTrue(recorded.isEmpty)
    }

    func testRapidDifferentKeysBothFire() {
        monitor.handle(type: .keyDown, event: keyEvent(98))  // F7
        now += 0.05                                           // 50ms 后
        monitor.handle(type: .keyDown, event: keyEvent(101)) // F9
        XCTAssertEqual(recorded, [.previousTrack, .nextTrack],
                       "不同键的节流互不影响")
    }

    func testSameKeyWithinDebounceFiresOnce() {
        monitor.handle(type: .keyDown, event: keyEvent(103)) // F11
        now += 0.05
        monitor.handle(type: .keyDown, event: keyEvent(103))
        XCTAssertEqual(recorded, [.volumeDown])
        now += 0.2 // 超过节流窗口后可再次触发
        monitor.handle(type: .keyDown, event: keyEvent(103))
        XCTAssertEqual(recorded, [.volumeDown, .volumeDown])
    }

    func testNonRepeatableActionIgnoresAutoRepeat() {
        let e1 = keyEvent(99)
        monitor.handle(type: .keyDown, event: e1)
        let e2 = keyEvent(99, isRepeat: true)
        monitor.handle(type: .keyDown, event: e2)
        XCTAssertEqual(recorded, [.missionControl])
    }

    func testKeyUpOfInterceptedKeyIsSwallowed() {
        let up = CGEvent(keyboardEventSource: nil, virtualKey: 99, keyDown: false)!
        XCTAssertTrue(monitor.handle(type: .keyUp, event: up) == nil,
                      "已启用键的 keyUp 也要吞掉,避免按键穿透")
        XCTAssertTrue(recorded.isEmpty) // keyUp 不触发动作
    }

    func testTapDisabledEventsPassThroughAndDoNotStopMonitor() {
        let e = keyEvent(99)
        // eventTap 为 nil(未 start)时走安全路径,不崩溃、不置 isRunning
        XCTAssertTrue(monitor.handle(type: .tapDisabledByTimeout, event: e) != nil)
        XCTAssertFalse(monitor.isRunning)
        XCTAssertTrue(monitor.handle(type: .tapDisabledByUserInput, event: e) != nil)
        XCTAssertFalse(monitor.isRunning)
    }

    func testTapDisabledByUserInputStopsMonitor() {
        monitor.startIfPossibleForTesting()
        XCTAssertTrue(monitor.isRunning)
        let e = keyEvent(99)
        monitor.handle(type: .tapDisabledByUserInput, event: e)
        XCTAssertFalse(monitor.isRunning, "权限被吊销后状态必须如实变为未运行")
    }
}
