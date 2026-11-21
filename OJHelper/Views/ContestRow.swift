import SwiftUI

/// 一行比赛，比赛页 / 收藏页共用。布局对齐 Android 版 ContestRow.java：
/// 站点 logo、标题 + 时间/时长 + 状态、☆ 收藏、铃铛提醒、日历按钮。
struct ContestRow: View {
    let contest: Contest
    var dateMode: Bool = false
    var showLogo: Bool = true
    var isFavorite: Bool
    var reminderLead: Int?
    var onOpen: () -> Void
    var onToggleFavorite: () -> Void
    var onSetReminder: (Int?) -> Void
    var onAddCalendar: () -> Void

    private var now: Date { Date() }

    private var subtitle: String {
        dateMode ? contest.span : "\(Contest.dayLabel(contest.start)) \(contest.span)"
    }

    var body: some View {
        HStack(spacing: 8) {
            if showLogo {
                LogoView(oj: contest.oj, size: 32)
                    .padding(.trailing, 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(contest.title)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)

                if contest.running(now) {
                    Text("进行中")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.green)
                } else if contest.finished(now) {
                    Text("已结束")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 17))
                    .foregroundStyle(isFavorite ? Theme.star : Theme.starOff)
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(.plain)

            reminderMenu

            Button(action: onAddCalendar) {
                Text("日历")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    private var reminderMenu: some View {
        Menu {
            if let lead = reminderLead {
                Button("关闭提醒") { onSetReminder(nil) }
                Divider()
                ForEach(ReminderOption.all, id: \.self) { option in
                    Button(label(for: option, current: lead)) { onSetReminder(option) }
                }
            } else {
                ForEach(ReminderOption.all, id: \.self) { option in
                    Button(label(for: option, current: nil)) { onSetReminder(option) }
                }
            }
        } label: {
            Image(systemName: reminderLead == nil ? "bell" : "bell.fill")
                .font(.system(size: 17))
                .foregroundStyle(reminderLead == nil ? Theme.sub : Theme.accent)
                .frame(width: 26, height: 30)
        }
    }

    private func label(for lead: Int, current: Int?) -> String {
        let title = lead == 0 ? "比赛开始时" : "提前 \(lead) 分钟"
        return current == lead ? "✓ \(title)" : title
    }
}

enum ReminderOption {
    static let all = [0, 5, 10, 15]
}

#Preview {
    ContestRow(
        contest: Contest(
            oj: .luogu,
            sid: "1",
            title: "【LGR-317-Div.2】洛谷 11 月月赛 II & P.A.TASKS S1",
            start: Date().addingTimeInterval(3600),
            end: Date().addingTimeInterval(7200),
            url: URL(string: "https://www.luogu.com.cn/contest/1")
        ),
        isFavorite: false,
        reminderLead: 10,
        onOpen: {},
        onToggleFavorite: {},
        onSetReminder: { _ in },
        onAddCalendar: {}
    )
    .padding(.horizontal, 14)
    .background(Theme.card)
}