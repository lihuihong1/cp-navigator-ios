import SwiftUI

struct ContestRow: View {
    let contest: Contest
    let isReminded: Bool
    let onSetReminder: (Int) -> Void
    let onCancel: () -> Void

    private var started: Bool {
        contest.start <= Date()
    }

    /// 和 Android 版一致的站点色。
    private var ojColor: Color {
        switch contest.oj {
        case .cf: return Color(red: 0.12, green: 0.54, blue: 0.80)
        case .atcoder: return Color(red: 0.23, green: 0.23, blue: 0.27)
        case .luogu: return Color(red: 0.00, green: 0.65, blue: 0.65)
        case .lanqiao: return Color(red: 0.12, green: 0.48, blue: 0.91)
        case .leetcode: return Color(red: 0.97, green: 0.62, blue: 0.11)
        case .nowcoder: return Color(red: 0.00, green: 0.73, blue: 0.42)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(Contest.hm(contest.start))
                    .font(.subheadline.weight(.semibold))
                Text(Contest.hm(contest.end))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contest.oj.short)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ojColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(ojColor)

                    if started {
                        Text("已开始")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(contest.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Menu {
                if isReminded {
                    Button("关闭提醒", role: .destructive) {
                        onCancel()
                    }
                    Divider()
                }
                Button("开赛时") { onSetReminder(0) }
                Button("提前 5 分钟") { onSetReminder(5) }
                Button("提前 10 分钟") { onSetReminder(10) }
                Button("提前 15 分钟") { onSetReminder(15) }
            } label: {
                Image(systemName: isReminded ? "bell.fill" : "bell")
                    .font(.system(size: 20))
                    .foregroundStyle(isReminded ? Color.accentColor : Color.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(started)
            .opacity(started ? 0.35 : 1)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    List {
        ContestRow(
            contest: SampleData.contests()[0],
            isReminded: true,
            onSetReminder: { _ in },
            onCancel: {}
        )
    }
}