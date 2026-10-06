import XCTest
@testable import FnBridge

final class FKeySettingsTests: XCTestCase {
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = UserDefaults(suiteName: "FKeySettingsTests")
        suite.removePersistentDomain(forName: "FKeySettingsTests")
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: "FKeySettingsTests")
        suite = nil
        super.tearDown()
    }

    func testKeyCodeMappingIsCompleteAndUnique() {
        let codes = FKeyAction.allCases.map(\.keyCode)
        XCTAssertEqual(codes.count, 12)
        XCTAssertEqual(Set(codes).count, 12, "每个 F 键键码必须唯一")
        XCTAssertEqual(FKeyAction.allCases.first?.keyCode, 122) // F1
        XCTAssertEqual(FKeyAction.allCases.last?.keyCode, 111)  // F12
    }

    func testDefaultEnabledExcludesUnsupported() {
        XCTAssertFalse(FKeySettings(defaults: suite).enabled.contains(.dictation))
        XCTAssertFalse(FKeySettings(defaults: suite).enabled.contains(.focus))
        XCTAssertTrue(FKeySettings(defaults: suite).enabled.contains(.missionControl))
    }

    func testPersistenceRoundTrip() {
        var s = FKeySettings(defaults: suite)
        s.setEnabled(.playPause, false)
        s.setEnabled(.focus, true) // 不支持的也允许写入,但见下一个测试
        let reloaded = FKeySettings(defaults: suite)
        XCTAssertFalse(reloaded.enabled.contains(.playPause))
        XCTAssertTrue(reloaded.enabled.contains(.focus))
    }

    func testMasterEnabledRoundTrip() {
        XCTAssertTrue(FKeySettings(defaults: suite).masterEnabled, "缺省 true")
        var s = FKeySettings(defaults: suite)
        s.masterEnabled = false
        XCTAssertFalse(FKeySettings(defaults: suite).masterEnabled)
    }

    func testUnsupportedActionIsNeverInterceptable() {
        var s = FKeySettings(defaults: suite)
        s.setEnabled(.dictation, true)
        s.setEnabled(.focus, true)
        XCTAssertFalse(s.isInterceptable(.dictation), "死键防护:F5 残留启用状态也不得拦截")
        XCTAssertFalse(s.isInterceptable(.focus), "死键防护:F6 残留启用状态也不得拦截")
    }

    func testGarbagePersistedValuesAreDropped() {
        suite.set(["missionControl", "notARealAction", "", "volumeUp"],
                  forKey: Prefs.enabledFKeyActions)
        let s = FKeySettings(defaults: suite)
        XCTAssertEqual(s.enabled, [.missionControl, .volumeUp])
    }

    func testEmptyPersistedSetDisablesEverything() {
        suite.set([String](), forKey: Prefs.enabledFKeyActions)
        XCTAssertTrue(FKeySettings(defaults: suite).enabled.isEmpty)
        XCTAssertFalse(FKeySettings(defaults: suite).isInterceptable(.missionControl))
    }

    func testResetToDefaultsRestoresDefaults() {
        var s = FKeySettings(defaults: suite)
        s.setEnabled(.volumeUp, false)
        s.resetToDefaults()
        XCTAssertEqual(FKeySettings(defaults: suite).enabled, FKeyAction.defaultEnabled)
    }

    func testPrefsDefaults() {
        XCTAssertTrue(Prefs.masterEnabled(defaults: suite))
        XCTAssertFalse(Prefs.showInDock(defaults: suite))
        XCTAssertTrue(Prefs.showInMenuBar(defaults: suite))
        suite.set(false, forKey: Prefs.masterEnabled)
        XCTAssertFalse(Prefs.masterEnabled(defaults: suite))
    }
}
