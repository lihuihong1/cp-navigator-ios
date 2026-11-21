import Foundation

/// 比赛列表的状态与缓存：先读磁盘缓存，再跑网络；单个站点失败不影响整体。
@MainActor
final class ContestStore: ObservableObject {
    @Published private(set) var contests: [Contest] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var siteErrors: [OJ: String] = [:]

    private struct Cache: Codable {
        let updatedAt: Date
        let contests: [Contest]
    }

    private let cacheURL: URL
    private let staleInterval: TimeInterval = 10 * 60

    init() {
        let manager = FileManager.default
        let directory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        cacheURL = directory.appendingPathComponent("contests.json")
        loadCache()
    }

    var grouped: [DayGroup] {
        var groups: [DayGroup] = []
        for contest in contests {
            let day = Contest.dayKey(contest.start)
            if var last = groups.last, last.day == day {
                last.items.append(contest)
                groups[groups.count - 1] = last
            } else {
                groups.append(DayGroup(day: day, items: [contest]))
            }
        }
        return groups
    }

    var failedSiteNames: String {
        OJ.allCases.filter { siteErrors[$0] != nil }.map(\.short).joined(separator: "、")
    }

    /// 首屏 / 回到前台时调用：缓存新鲜就跳过，避免每次切 Tab 都打网络。
    func refreshIfStale() async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < staleInterval {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let results = await ContestAPI.fetchAll()
        var merged: [Contest] = []
        var errors: [OJ: String] = [:]
        for oj in OJ.allCases {
            guard let result = results[oj] else { continue }
            switch result {
            case .success(let list):
                merged.append(contentsOf: list)
            case .failure(let error):
                errors[oj] = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }

        var seen = Set<String>()
        var unique: [Contest] = []
        for contest in merged where seen.insert(contest.id).inserted {
            unique.append(contest)
        }

        // 一个站点都没成功时保留旧数据，只更新错误提示。
        if !unique.isEmpty {
            contests = unique.sorted { $0.start < $1.start }
            lastUpdated = Date()
            saveCache()
        }
        siteErrors = errors
    }

    // MARK: - 缓存

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else {
            return
        }
        contests = cache.contests.sorted { $0.start < $1.start }
        lastUpdated = cache.updatedAt
    }

    private func saveCache() {
        guard let updatedAt = lastUpdated else { return }
        let cache = Cache(updatedAt: updatedAt, contests: contests)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}