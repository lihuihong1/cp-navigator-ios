import SwiftUI

struct SettingsView: View {
    @ObservedObject var notifier: NotificationManager

    @State private var message: String?

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("通知") {
                    LabeledContent("权限", value: notifier.authorized ? "已允许" : "未允许")
                    LabeledContent("待触发提醒", value: "\(notifier.pending.count) 条")

                    Button("发送测试通知（5 秒后）") {
                        Task {
                            let ok = await notifier.sendTest()
                            message = ok ? "已发送，5 秒后请看屏幕顶部" : (notifier.lastError ?? "发送失败")
                        }
                    }

                    Button("清除所有提醒", role: .destructive) {
                        Task {
                            await notifier.cancelAll()
                            message = "已清除"
                        }
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: version)
                    Text("P0 骨架：比赛为内置示例数据（相对当前时间生成），本地通知已可用；真实抓取与日历写入在后续版本接入。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
            .alert("提示", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("好", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

#Preview {
    SettingsView(notifier: NotificationManager.shared)
}