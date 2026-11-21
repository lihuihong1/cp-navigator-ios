import Foundation

/// 一场比赛。P0 阶段先用内置示例数据，P1 接真实抓取。
struct Contest: Identifiable, Hashable {
    let id: String
    /// 站点短名：洛谷 / CF / AtCoder / 蓝桥 …
    let oj: String
    let title: String
    let start: Date
    let end: Date
    let url: URL?

    var timeRange: String {
        "\(Self.hm(start)) - \(Self.hm(end))"
    }

    static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd EEEE"
        return f.string(from: date)
    }
}

@MainActor
final class ContestStore: ObservableObject {
    @Published private(set) var contests: [Contest] = SampleData.contests()

    var grouped: [DayGroup] {
        let sorted = contests.sorted { $0.start < $1.start }
        var order: [String] = []
        var buckets: [String: [Contest]] = [:]
        for c in sorted {
            let key = Contest.dayKey(c.start)
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = []
            }
            buckets[key]?.append(c)
        }
        return order.map { DayGroup(day: $0, items: buckets[$0] ?? []) }
    }

    func contest(id: String) -> Contest? {
        contests.first { $0.id == id }
    }
}