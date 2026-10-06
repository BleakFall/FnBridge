import AppKit

/// AppKit 入口:AppDelegate 持久持有设置窗口,reopen 恢复不依赖 SwiftUI WindowGroup。
@main
struct FnBridgeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
