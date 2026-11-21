import Foundation

/// 支持的 OJ。
enum OJ: String, Codable, CaseIterable, Identifiable {
    case cf
    case atcoder
    case luogu
    case lanqiao
    case leetcode
    case nowcoder

    var id: String { rawValue }

    /// 列表徽标上的短名。
    var short: String {
        switch self {
        case .cf: return "CF"
        case .atcoder: return "AtCoder"
        case .luogu: return "洛谷"
        case .lanqiao: return "蓝桥"
        case .leetcode: return "力扣"
        case .nowcoder: return "牛客"
        }
    }

    /// 完整站点名，写通知正文/日历描述时用。
    var name: String {
        switch self {
        case .cf: return "Codeforces"
        case .atcoder: return "AtCoder"
        case .luogu: return "洛谷"
        case .lanqiao: return "蓝桥云课"
        case .leetcode: return "力扣"
        case .nowcoder: return "牛客"
        }
    }
}

/// 一场比赛。时间均为绝对时间，展示时用本地时区。
struct Contest: Identifiable, Hashable, Codable {
    let oj: OJ
    let sid: String
    let title: String
    let start: Date
    let end: Date
    let url: URL?

    var id: String { "\(oj.rawValue)-\(sid)" }

    var timeRange: String { "\(Self.hm(start)) - \(Self.hm(end))" }

    /// 比赛页统一用北京时间，避免跨时区时“今天/明天”分桶漂移。
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = calendar.timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd EEEE"
        return f.string(from: date)
    }

    /// 抓取窗口：今天 0 点 ~ 7 天后。今天已结束的也保留（和 Android 版一致）。
    static func inWindow(_ start: Date, _ end: Date, now: Date = Date()) -> Bool {
        let dayStart = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: 7, to: dayStart) else {
            return true
        }
        return start < windowEnd && end > dayStart
    }
}