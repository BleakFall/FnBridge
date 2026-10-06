import AppKit
import Combine
import CoreGraphics
import SwiftUI

struct PermissionsTab: View {
    @State private var canListen = false
    @State private var canPost = false
    @State private var tapRunning = false
    @State private var message: String?

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                statusRow(ok: canListen,
                          text: canListen ? String(localized: "输入监控:已授权") : String(localized: "输入监控:未授权"))
                statusRow(ok: canPost,
                          text: canPost ? String(localized: "辅助功能:已授权") : String(localized: "辅助功能:未授权"))
                statusRow(ok: tapRunning,
                          text: tapRunning ? String(localized: "事件监听中") : String(localized: "事件监听未启动"))
            } header: {
                Text("状态")
            } footer: {
                Text("授权后请完全退出并重新打开本 App 才会生效。")
            }

            Section {
                if !canPost {
                    Button("授权辅助功能") { requestPostAccess() }
                }
                if !canListen {
                    Button("请求输入监控权限") { requestListenAccess() }
                }
                Button(tapRunning ? "停止监听" : "开始监听") { toggleTap() }
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("操作")
            }

            Section {
                Text(String(format: String(localized: "最近按键码:%lld(-1 = 尚未收到)"), KeyMonitor.shared.lastKeyCode))
                if let action = KeyMonitor.shared.lastAction {
                    Text(String(format: String(localized: "上次触发:%@ → %@"), action.keyLabel, action.title))
                }
            } header: {
                Text("诊断")
            } footer: {
                Text("按下的键若未显示在此,说明系统没有把该键交给我们(常见于妙控键盘的媒体层按键)")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private func statusRow(ok: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func refresh() {
        canListen = CGPreflightListenEventAccess()
        canPost = CGPreflightPostEventAccess()
        tapRunning = KeyMonitor.shared.isRunning
    }

    private func requestListenAccess() {
        if !CGRequestListenEventAccess() {
            openPrivacyPane("Privacy_ListenEvent")
        }
        refresh()
    }

    private func requestPostAccess() {
        if !CGRequestPostEventAccess() {
            openPrivacyPane("Privacy_Accessibility")
        }
        refresh()
    }

    /// 打开"隐私与安全性"里对应的权限面板，让用户手动勾选本 App。
    /// CGRequest* 首次可弹内联提示，但从 Xcode / 未装到 /Applications 时经常静默失败，
    /// 所以请求仍未授权时直接跳到系统设置面板兜底。
    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func toggleTap() {
        if KeyMonitor.shared.isRunning {
            KeyMonitor.shared.stop()
        } else {
            if !KeyMonitor.shared.start() {
                message = String(localized: "监听启动失败:请在“系统设置 → 隐私与安全性 → 输入监控”勾选本 App,然后完全退出重开。")
            } else {
                message = nil
            }
        }
        refresh()
    }
}
