import Foundation
import UserNotifications

/// 本地通知（开赛提醒）。iOS 的本地通知由系统调度，杀进程也会响，不需要精确定时权限。
@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// identifier -> 提前分钟数；只包含仍待触发的提醒。
    @Published private(set) var leads: [String: Int] = [:]
    @Published private(set) var authorized = false
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    private init() {}

    var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "已允许"
        case .denied: return "已关闭"
        case .notDetermined: return "未设置"
        @unknown default: return "未知"
        }
    }

    static func identifier(for contest: Contest) -> String {
        "contest-\(contest.id)"
    }

    var pendingCount: Int { leads.count }

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
        var out: [String: Int] = [:]
        for request in requests where request.identifier.hasPrefix("contest-") {
            out[request.identifier] = request.content.userInfo["lead"] as? Int ?? 0
        }
        leads = out
        status = await center.notificationSettings().authorizationStatus
    }

    /// 已设置的提前量，nil 表示没设。
    func lead(for contest: Contest) -> Int? {
        leads[Self.identifier(for: contest)]
    }

    func isReminded(_ contest: Contest) -> Bool {
        lead(for: contest) != nil
    }

    /// 给某场比赛排一条通知；lead 为提前分钟数，0 表示开赛时。
    @discardableResult
    func schedule(_ contest: Contest, lead: Int) async -> Bool {
        if status == .notDetermined {
            await requestAuthorization()
        }
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
        content.userInfo = ["lead": lead]

        var comps = Contest.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        comps.timeZone = Contest.calendar.timeZone
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