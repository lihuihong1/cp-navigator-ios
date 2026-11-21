import Foundation

/// 一次查询里某个站点的结果。
struct SiteResult: Identifiable {
    let oj: OJ
    var list: [Contest]
    var error: Error?

    var id: OJ { oj }
    var failed: Bool { error != nil }
}

/// 「按日期」视图里的一天。
struct DayBucket: Identifiable {
    let day: Date
    let list: [Contest]

    var id: Date { day }
}

/// 比赛数据：只在内存里保存本次查询结果（和 Android 版一致，退出即清空）。
/// 收藏与「按日期/按平台」偏好落在 UserDefaults。
@MainActor
final class ContestStore: ObservableObject {

    /// nil 表示本进程还没查过；进入页面不自动查询。
    @Published private(set) var results: [SiteResult]?
    @Published private(set) var lastQueriedAt: Date?
    @Published private(set) var isQuerying = false

    /// 已启用的站点，至少一个。
    @Published private(set) var enabled: Set<OJ> {
        didSet { saveEnabled() }
    }

    /// true = 按日期，false = 按平台。
    @Published var dateMode: Bool {
        didSet { UserDefaults.standard.set(dateMode, forKey: Keys.dateMode) }
    }

    /// 收藏的整条记录（不依赖后续查询是否还能抓到它）。
    @Published private(set) var favorites: [Contest] {
        didSet { saveFavorites() }
    }

    private enum Keys {
        static let enabled = "contest.enabled.v1"
        static let dateMode = "contest.dateMode.v1"
        static let favorites = "contest.favorites.v1"
    }

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.array(forKey: Keys.enabled) as? [String] {
            let set = Set(raw.compactMap(OJ.init(rawValue:)))
            enabled = set.isEmpty ? Set(OJ.allCases) : set
        } else {
            enabled = Set(OJ.allCases)
        }
        dateMode = defaults.bool(forKey: Keys.dateMode)
        if let data = defaults.data(forKey: Keys.favorites),
           let list = try? JSONDecoder().decode([Contest].self, from: data) {
            favorites = list
        } else {
            favorites = []
        }
    }

    // MARK: - 查询

    var sites: [OJ] { OJ.allCases.filter { enabled.contains($0) } }

    var sourceNames: String { sites.map(\.short).joined(separator: " / ") }

    var totalCount: Int { (results ?? []).reduce(0) { $0 + $1.list.count } }

    var failedCount: Int { (results ?? []).filter(\.failed).count }

    func query() async {
        guard !isQuerying else { return }
        let sites = self.sites
        guard !sites.isEmpty else { return }
        isQuerying = true
        let map = await ContestAPI.fetchAll(sites)
        var out: [SiteResult] = []
        for oj in sites {
            switch map[oj] {
            case .success(let list):
                out.append(SiteResult(oj: oj, list: list, error: nil))
            case .failure(let error):
                out.append(SiteResult(oj: oj, list: [], error: error))
            case nil:
                out.append(SiteResult(oj: oj, list: [], error: URLError(.unknown)))
            }
        }
        results = out
        lastQueriedAt = Date()
        isQuerying = false
    }

    /// 平台选择变了：旧结果不再代表当前配置，回到引导页。
    func setEnabled(_ set: Set<OJ>) {
        guard !set.isEmpty else { return }
        enabled = set
        results = nil
        lastQueriedAt = nil
    }

    // MARK: - 收藏

    func isFavorite(_ contest: Contest) -> Bool {
        favorites.contains { $0.id == contest.id }
    }

    @discardableResult
    func toggleFavorite(_ contest: Contest) -> Bool {
        if let index = favorites.firstIndex(where: { $0.id == contest.id }) {
            favorites.remove(at: index)
            return false
        }
        favorites.insert(contest, at: 0)
        return true
    }

    func clearFavorites() {
        favorites = []
    }

    // MARK: - 分桶

    /// 按日期：今天起 7 个自然日；跨零点的比赛算在开始那天，昨天开始且此刻未结束的归今天。
    func dayBuckets(now: Date = Date()) -> [DayBucket] {
        let all = (results ?? []).flatMap(\.list)
        let today = Contest.startOfToday(now)
        return (0..<7).map { offset in
            let start = Contest.calendar.date(byAdding: .day, value: offset, to: today)!
            let end = Contest.calendar.date(byAdding: .day, value: 1, to: start)!
            let list = all.filter { contest in
                let carry = offset == 0 && contest.start < start && contest.end > start
                return (contest.start >= start && contest.start < end) || carry
            }
            return DayBucket(day: start, list: list.sorted(by: Contest.sortByStart))
        }
    }

    private func saveEnabled() {
        UserDefaults.standard.set(enabled.map(\.rawValue).sorted(), forKey: Keys.enabled)
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: Keys.favorites)
        }
    }
}

extension Contest {
    static func sortByStart(_ a: Contest, _ b: Contest) -> Bool {
        if a.start != b.start { return a.start < b.start }
        return a.oj.rawValue < b.oj.rawValue
    }
}