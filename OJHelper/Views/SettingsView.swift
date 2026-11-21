import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var notify: NotificationManager

    @State private var message: String?

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Line()
            ScrollView {
                VStack(spacing: 10) {
                    notifyCard
                    aboutCard
                }
                .padding(12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .alert("提示", isPresented: messageBinding) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var header: some View {
        Text("我的")
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Theme.card)
    }

    private var notifyCard: some View {
        VStack(spacing: 0) {
            infoRow("通知权限", value: notify.statusText)
            Line().padding(.horizontal, 14)
            infoRow("待触发提醒", value: "\(notify.pendingCount) 条")
            Line().padding(.horizontal, 14)
            actionRow("发送测试通知（5 秒后）", color: Theme.accent) {
                Task {
                    let ok = await notify.sendTest()
                    message = ok ? "已发送，5 秒后请看屏幕顶部" : (notify.lastError ?? "发送失败")
                }
            }
            Line().padding(.horizontal, 14)
            actionRow("清除所有提醒", color: Theme.red) {
                Task {
                    await notify.cancelAll()
                    message = "已清除"
                }
            }
        }
        .card()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            infoRow("版本", value: version)
            Line().padding(.horizontal, 14)
            Text("1.0：六个 OJ 的真实比赛、开赛提醒、日历写入。收藏只保存在本机；榜单与成绩统计在后续版本接入。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .padding(14)
        }
        .card()
    }

    private func infoRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    private func actionRow(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: title.contains("清除") ? .regular : .semibold))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var messageBinding: Binding<Bool> {
        Binding(get: { message != nil }, set: { if !$0 { message = nil } })
    }
}