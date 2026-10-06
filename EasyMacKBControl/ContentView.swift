import SwiftUI
import Combine

struct ContentView: View {
    @State private var canListen = false      // 输入监控（读按键）
    @State private var canPost = false        // 辅助功能（发事件）
    @State private var tapRunning = false
    @State private var message: String?

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EasyMacKBControl")
                .font(.title.bold())
            Text("把 HHKB 的 F3 转成“调度中心”（Mission Control）")
                .foregroundStyle(.secondary)

            Divider()

            statusRow(ok: canListen, text: canListen ? "输入监控：已授权" : "输入监控：未授权")
            statusRow(ok: canPost, text: canPost ? "辅助功能：已授权" : "辅助功能：未授权")
            statusRow(ok: tapRunning, text: tapRunning ? "事件监听中" : "事件监听未启动")

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 诊断：按 Fn+3 时“最近按键码”应变成 99（F3）
            let kc = KeyMonitor.shared.lastKeyCode
            Text("诊断：最近按键码 \(kc)（F3=99，F5=96，-1=尚未收到按键）")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let trig = KeyMonitor.shared.lastTriggerDate {
                Text("诊断：上次触发 \(trig.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !canPost {
                Button("授权辅助功能") { requestPostAccess() }
            }
            if !canListen {
                Button("请求输入监控权限") { requestListenAccess() }
            }

            Button(tapRunning ? "停止监听" : "开始监听") { toggleTap() }

            Text("重要：授权后请【完全退出并重新打开】本 App 才会生效。\n从 Xcode 运行时权限偶发不生效，建议用 Xcode 打包导出到 /Applications 后再授权。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            refresh()
            startTap()
        }
        .onReceive(timer) { _ in
            refresh()
        }
    }

    private func statusRow(ok: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func refresh() {
        canListen = CGPreflightListenEventAccess()
        canPost = CGPreflightPostEventAccess()
    }

    private func requestListenAccess() {
        _ = CGRequestListenEventAccess()
        refresh()
    }

    private func requestPostAccess() {
        _ = CGRequestPostEventAccess()
        refresh()
    }

    private func startTap() {
        tapRunning = KeyMonitor.shared.start()
        message = tapRunning ? nil : "事件钩子创建失败：请在“系统设置 → 隐私与安全性 → 输入监控”勾选本 App，然后完全退出重开。"
    }

    private func toggleTap() {
        if KeyMonitor.shared.isRunning {
            KeyMonitor.shared.stop()
            tapRunning = false
            message = nil
        } else {
            startTap()
        }
    }
}
