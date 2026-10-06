import SwiftUI

struct KeyMappingTab: View {
    @State private var settings = FKeySettings()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("F 区功能映射").font(.headline)
                Spacer()
                Button("恢复默认") {
                    settings.resetToDefaults()
                }
                .controlSize(.small)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(FKeyAction.allCases) { action in
                        fKeyRow(action)
                    }
                }
            }

            Text("开启后,该 F 键会被本 App 接管并转成对应系统功能;关闭则保持普通 F 键。注意:拦截对所有键盘生效(包括笔记本内置键盘)。F5(听写)与 F6(专注模式)因 macOS 系统限制,暂不支持。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(4)
    }

    private func fKeyRow(_ action: FKeyAction) -> some View {
        HStack(spacing: 12) {
            Text(action.keyLabel)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(width: 44, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(action.supported
                              ? Color.accentColor.opacity(0.15)
                              : Color.secondary.opacity(0.12))
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
            get: { settings.enabled.contains(action) },
            set: { settings.setEnabled(action, $0) }
        )
    }
}
