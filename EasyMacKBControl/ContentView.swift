import SwiftUI
import Combine

struct ContentView: View {
    @State private var canListen = false      // 输入监控（读按键）
    @State private var canPost = false        // 辅助功能（发事件）
    @State private var tapRunning = false
    @State private var message: String?

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                statusSection
                Divider()
                fkeySection
                Divider()
                permissionSection
                diagnosticSection
            }
            .padding(24)
        }
        .frame(width: 540, height: 660)
        .onAppear {
            refresh()
            startTap()
        }
        .onReceive(timer) { _ in
            refresh()
        }
    }

    // MARK: - 顶部

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EasyMacKBControl")
                .font(.title.bold())
            Text("把外接键盘的标准 F 键（如 HHKB 的 Fn+数字）转换成妙控键盘 F 区功能")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 权限与运行状态

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusRow(ok: canListen, text: canListen ? "输入监控：已授权" : "输入监控：未授权")
            statusRow(ok: canPost, text: canPost ? "辅助功能：已授权" : "辅助功能：未授权")
            statusRow(ok: tapRunning, text: tapRunning ? "事件监听中" : "事件监听未启动")
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

    // MARK: - F 区映射列表

    private var fkeySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("F 区功能映射")
                    .font(.headline)
                Spacer()
                Button("恢复默认") {
                    var settings = FKeySettings()
                    settings.resetToDefaults()
                }
                    .controlSize(.small)
            }

            ForEach(FKeyAction.allCases) { action in
                fKeyRow(action)
            }

            Text("说明：开启后，该 F 键会被本 App 接管并转成对应系统功能；关闭则保持普通 F 键。F5（听写）与 F6（专注模式）因 macOS 未提供公开接口，暂不支持。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func fKeyRow(_ action: FKeyAction) -> some View {
        HStack(spacing: 12) {
            Text(action.keyLabel)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(width: 40, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                )

            Text(action.title)
                .foregroundStyle(action.supported ? .primary : .secondary)

            Spacer()

            if action.supported {
                Toggle("", isOn: binding(for: action))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            } else {
                Text("暂不支持")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func binding(for action: FKeyAction) -> Binding<Bool> {
        Binding(
            get: { FKeySettings().enabled.contains(action) },
            set: { on in
                var settings = FKeySettings()
                settings.setEnabled(action, on)
            }
        )
    }

    // MARK: - 权限与启停

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !canPost || !canListen {
                HStack(spacing: 10) {
                    if !canPost {
                        Button("授权辅助功能") { requestPostAccess() }
                    }
                    if !canListen {
                        Button("请求输入监控权限") { requestListenAccess() }
                    }
                }
            }

            Button(tapRunning ? "停止监听" : "开始监听") { toggleTap() }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("重要：授权后请【完全退出并重新打开】本 App 才会生效。\n从 Xcode 运行时权限偶发不生效，建议用 Xcode 打包导出到 /Applications 后再授权。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 诊断

    private var diagnosticSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            let kc = KeyMonitor.shared.lastKeyCode
            Text("诊断：最近按键码 \(kc)（-1=尚未收到按键）")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let action = KeyMonitor.shared.lastAction {
                Text("诊断：上次触发 \(action.keyLabel) → \(action.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let trig = KeyMonitor.shared.lastTriggerDate {
                Text("诊断：上次触发 \(trig.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 方法

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
