import XCTest
@testable import EasyMacKBControl

final class SystemEventPosterTests: XCTestCase {
    func testAuxEventData1Encoding() {
        // 按下 = keyCode << 16 | 0xA00;抬起 = keyCode << 16 | 0xB00(IOKit NX 规范)
        XCTAssertEqual(SystemEventPoster.auxEventData1(key: 0, down: true), 0xA00)
        XCTAssertEqual(SystemEventPoster.auxEventData1(key: 0, down: false), 0xB00)
        XCTAssertEqual(SystemEventPoster.auxEventData1(key: 16, down: true), 16 << 16 | 0xA00)
        XCTAssertEqual(SystemEventPoster.auxEventData1(key: 3, down: false), 3 << 16 | 0xB00)
    }

    func testAuxKeyMappingMatchesIOKitConstants() {
        // NX_KEYTYPE_* 常量值,与 IOKit hidsystem 一致
        let expected: [FKeyAction: Int32] = [
            .brightnessDown: 3, .brightnessUp: 2,
            .previousTrack: 18, .playPause: 16, .nextTrack: 17,
            .mute: 7, .volumeDown: 1, .volumeUp: 0,
        ]
        XCTAssertEqual(SystemEventPoster.auxKeyByAction, expected)
    }

    func testEveryRepeatableActionHasImplementationPath() {
        // 每个受支持的动作都必须有发送路径:媒体/亮度/音量走 auxKeyByAction,
        // missionControl 走 App 启动路径,spotlight 走 Cmd+Space 路径。
        for action in FKeyAction.allCases where action.supported {
            let hasPath = SystemEventPoster.auxKeyByAction[action] != nil
                || action == .missionControl
                || action == .spotlight
            XCTAssertTrue(hasPath, "\(action.rawValue) 缺少发送路径")
        }
    }
}
