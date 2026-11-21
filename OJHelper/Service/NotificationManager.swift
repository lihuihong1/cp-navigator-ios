import Foundation
import UserNotifications

/// 本地通知（开赛提醒）。iOS 的本地通知由系统调度，杀进程也会响，不需要精确定时权限。
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// 已排程的 identifier 集合，形如 "contest-sample-luogu"。
    @Published private(set) var pending: Set<String> = []
    @Published private(set) var authorized = false
    @Published private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    private init() {}

    static func identifier(for contest: Contest) -> String {
        "contest-\(contest.id)"
    }

    func requestAuthorization() async {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
            lastError = error.localizedDescription
        }
        await refresh()
    }

    func refresh() async {
        let requests = await center.pendingNotificationRequests()
        pending = Set(requests.map { $0.identifier })
    }

    func isReminded(_ contest: Contest) -> Bool {
        pending.contains(Self.identifier(for: contest))
    }

    /// 给某场比赛排一条通知；lead 为提前分钟数，0 表示开赛时。
    @discardableResult
    func schedule(_ contest: Contest, lead: Int) async -> Bool {
        let fireAt = contest.start.addingTimeInterval(Double(-lead) * 60)
        guard fireAt > Date() else {
            lastError = "比赛已开始，无法设置提醒"
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = lead <= 0 ? "比赛马上开始" : "比赛将在 \(lead) 分钟后开始"
        content.body = "[\(contest.oj.name)] \(contest.title)\n\(contest.timeRange)"
        content.sound = .default
        content.threadIdentifier = "contest"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: contest),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            lastError = nil
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func cancel(_ contest: Contest) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: contest)])
        await refresh()
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        await refresh()
    }

    /// 5 秒后的测试通知，用来验证通知权限与横幅。
    @discardableResult
    func sendTest() async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "测试通知"
        content.body = "如果你看到这条，说明本机通知正常。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        do {
            try await center.add(
                UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)
            )
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}