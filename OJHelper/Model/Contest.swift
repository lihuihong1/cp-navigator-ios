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

    /// 资源目录里的站点 logo。
    var logoName: String {
        switch self {
        case .cf: return "logo_cf"
        case .atcoder: return "logo_atcoder"
        case .luogu: return "logo_luogu"
        case .lanqiao: return "logo_lanqiao"
        case .leetcode: return "logo_lc"
        case .nowcoder: return "logo_nowcoder"
        }
    }

    /// 徽标底色（没有 logo 时兜底）。
    var color: UInt32 {
        switch self {
        case .cf: return 0x1F8ACB
        case .atcoder: return 0x3A3A46
        case .luogu: return 0x00A6A6
        case .lanqiao: return 0x1E7BE8
        case .leetcode: return 0xF89F1B
        case .nowcoder: return 0x00B96B
        }
    }
}

/// 一场比赛。时间均为绝对时间，展示统一按北京时间。
struct Contest: Identifiable, Hashable, Codable {
    let oj: OJ
    let sid: String
    let title: String
    let start: Date
    let end: Date
    let url: URL?

    var id: String { "\(oj.rawValue)-\(sid)" }

    func running(_ now: Date = Date()) -> Bool { start <= now && end > now }
    func finished(_ now: Date = Date()) -> Bool { end <= now }

    /// "14:00-19:00 · 5 小时"
    var timeRange: String { "\(Self.hm(start))-\(Self.hm(end))" }

    var durationText: String {
        let minutes = max(0, Int(end.timeIntervalSince(start)) / 60)
        if minutes < 60 { return "\(minutes) 分钟" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) 小时" : "\(h) 小时 \(m) 分"
    }

    var span: String { "\(timeRange) · \(durationText)" }

    /// 比赛页统一用北京时间，避免跨时区时“今天/明天”分桶漂移。
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()

    static func hm(_ date: Date) -> String {
        formatter("HH:mm").string(from: date)
    }

    static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }

    static func startOfToday(_ now: Date = Date()) -> Date {
        calendar.startOfDay(for: now)
    }

    static func windowText(_ now: Date = Date()) -> String {
        let start = startOfToday(now)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!.addingTimeInterval(-1)
        return "\(formatter("yyyy-MM-dd").string(from: start)) ~ \(formatter("yyyy-MM-dd").string(from: end))"
    }

    /// 与今天相差几个自然日：0=今天，1=明天……
    static func dayDiff(_ date: Date, now: Date = Date()) -> Int {
        let d = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: startOfToday(now), to: d).day ?? 0
    }

    /// 今天 / 明天 / 后天 / 12-05 周六
    static func dayLabel(_ date: Date) -> String {
        let diff = dayDiff(date)
        if diff == 0 { return "今天" }
        if diff == 1 { return "明天" }
        if diff == 2 { return "后天" }
        return formatter("yyyy-MM-dd EEE").string(from: date)
    }

    /// 今天 2026-11-20 周五 / 2026-11-23 周一
    static func dayFull(_ date: Date) -> String {
        let md = formatter("yyyy-MM-dd EEE").string(from: date)
        let diff = dayDiff(date)
        if diff == 0 { return "今天 \(md)" }
        if diff == 1 { return "明天 \(md)" }
        if diff == 2 { return "后天 \(md)" }
        return md
    }

    /// 抓取窗口：今天 0 点 ~ 7 天后。今天已结束的也保留（和 Android 版一致）。
    static func inWindow(_ start: Date, _ end: Date, now: Date = Date()) -> Bool {
        let dayStart = self.startOfToday(now)
        guard let windowEnd = calendar.date(byAdding: .day, value: 7, to: dayStart) else {
            return true
        }
        return start < windowEnd && end > dayStart
    }
}