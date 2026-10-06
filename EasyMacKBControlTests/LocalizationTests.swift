import XCTest
@testable import EasyMacKBControl

final class LocalizationTests: XCTestCase {
    /// 读取指定语言 lproj 里的翻译（不依赖进程 locale，可靠、可复现）。
    private func string(_ key: String, in language: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            XCTFail("缺少 \(language).lproj")
            return key
        }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private func en(_ key: String) -> String { string(key, in: "en") }
    private func zh(_ key: String) -> String { string(key, in: "zh-Hans") }

    /// 菜单栏与设置界面字符串必须有英文翻译（防回归：删翻译会导致失败）。
    func testEnglishTranslationsExist() {
        let keys = [
            "启用 F 键转换", "打开设置…", "开机自启", "退出 EasyMacKBControl",
            "✓ 运行中", "⚠️ 缺少权限,点击前往系统设置", "⚠️ 监听未启动",
            "通用", "按键映射", "权限与诊断",
            "输入监控:已授权", "输入监控:未授权",
            "辅助功能:已授权", "辅助功能:未授权",
            "事件监听中", "事件监听未启动", "开始监听", "停止监听",
        ]
        for key in keys {
            XCTAssertNotEqual(en(key), key, "\(key) 缺少英文翻译")
        }
    }

    /// F 键功能名必须有英文翻译。
    func testFKeyActionTitlesHaveEnglishTranslations() {
        for action in FKeyAction.allCases {
            XCTAssertNotEqual(en(action.titleKey), action.titleKey,
                              "\(action.rawValue) 缺少英文翻译")
        }
    }

    /// zh-Hans 源语言字符串必须可用（值与键一致）。
    func testChineseSourceStringsAvailable() {
        for key in ["通用", "按键映射", "权限与诊断", "降低屏幕亮度", "静音", "输入监控:已授权"] {
            XCTAssertEqual(zh(key), key, "\(key) 缺少 zh-Hans 源字符串")
        }
    }
}
