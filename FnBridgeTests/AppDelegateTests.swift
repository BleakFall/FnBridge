import AppKit
import XCTest
@testable import FnBridge

final class AppDelegateTests: XCTestCase {
    func testDoesNotTerminateAfterLastWindowClosed() {
        let delegate = AppDelegate()
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }

    func testHandlesReopen() {
        let delegate = AppDelegate()
        XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
    }

    /// 评审 #1:reopen 恢复必须由 AppDelegate 持久持有窗口,而非依赖已关闭窗口的 onReceive 观察者。
    func testShowSettingsCreatesAndReusesWindow() {
        let delegate = AppDelegate()
        delegate.showSettings()
        let first = delegate.settingsWindow
        XCTAssertNotNil(first, "showSettings 应创建持久窗口")
        delegate.showSettings()
        XCTAssertTrue(delegate.settingsWindow === first, "再次 showSettings 应复用同一窗口(而非重复创建)")
    }
}
