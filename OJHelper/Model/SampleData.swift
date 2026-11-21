import Foundation

/// 只给 SwiftUI 预览用的示例比赛；App 运行时用的是真实抓取 + 缓存。
enum SampleData {
    static func contests() -> [Contest] {
        let now = Date()
        let cal = Contest.calendar

        func add(minutes: Int) -> Date {
            now.addingTimeInterval(Double(minutes) * 60)
        }

        func tomorrow(hour: Int, minute: Int) -> Date {
            let base = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        return [
            Contest(
                oj: .luogu,
                sid: "sample-luogu",
                title: "[LGR-318] 洛谷 12 月月赛",
                start: add(minutes: 25),
                end: add(minutes: 25 + 120),
                url: URL(string: "https://www.luogu.com.cn/contest/list")
            ),
            Contest(
                oj: .cf,
                sid: "sample-cf",
                title: "Codeforces Round 1137 (Div. 2)",
                start: add(minutes: 180),
                end: add(minutes: 180 + 120),
                url: URL(string: "https://codeforces.com/contests")
            ),
            Contest(
                oj: .atcoder,
                sid: "sample-atc",
                title: "AtCoder Beginner Contest 487",
                start: tomorrow(hour: 20, minute: 0),
                end: tomorrow(hour: 21, minute: 40),
                url: URL(string: "https://atcoder.jp/contests/")
            ),
            Contest(
                oj: .lanqiao,
                sid: "sample-lanqiao",
                title: "第 42 场 蓝桥·算法挑战赛",
                start: tomorrow(hour: 19, minute: 0),
                end: tomorrow(hour: 21, minute: 0),
                url: URL(string: "https://www.lanqiao.cn/contests/")
            ),
        ]
    }
}