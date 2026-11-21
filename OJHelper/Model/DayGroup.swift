import Foundation

/// 列表里的“一天”：日期标题 + 当天的比赛。
struct DayGroup: Identifiable {
    let day: String
    var items: [Contest]

    var id: String { day }
}