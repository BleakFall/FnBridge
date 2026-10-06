import XCTest
@testable import EasyMacKBControl

final class LocalizationTests: XCTestCase {
    private let en = Locale(identifier: "en")

    /// 菜单栏状态行标题必须随 locale 本地化(评审 #2:裸字符串在 en 环境下仍是中文)。
    func testMenuBarStatusTitleLocalizes() {
        XCTAssertEqual(MenuBarController.statusLineTitle(canListen: true, canPost: true, monitoring: true, locale: en),
                       "✓ Running")
        XCTAssertEqual(MenuBarController.statusLineTitle(canListen: false, canPost: true, monitoring: false, locale: en),
                       "⚠️ Missing permission — click to open System Settings")
        XCTAssertEqual(MenuBarController.statusLineTitle(canListen: true, canPost: true, monitoring: false, locale: en),
                       "⚠️ Not monitoring")
    }

    /// 菜单栏其余字符串键必须有英文翻译(防回归:删翻译会导致失败)。
    func testMenuBarKeysHaveEnglishTranslations() {
        let keys = [
            "启用 F 键转换",
            "打开设置…",
            "开机自启",
            "退出 EasyMacKBControl",
        ]
        for key in keys {
            let translated = String(localized: String.LocalizationValue(key),
                                    bundle: .main,
                                    locale: en)
            XCTAssertNotEqual(translated, key, "菜单栏字符串 \(key) 缺少英文翻译")
        }
    }
}
