import SwiftUI

struct StatEntry: Codable, Equatable {
    var solved: Int = -1
    var rating: Double?
    var extra: String?
    var updatedAt: Date?
    var error: String?
}

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var handles: [StatSite: String] = [:]
    @Published private(set) var entries: [StatSite: StatEntry] = [:]
    @Published private(set) var loading: Set<StatSite> = []

    private let defaults = UserDefaults.standard
    private let handlesKey = "stats.handles.v1"
    private let entriesKey = "stats.entries.v1"
    private let queue = DispatchQueue(label: "stats.store")

    init() {
        load()
    }

    func handle(_ site: StatSite) -> String {
        handles[site] ?? ""
    }

    func setHandle(_ site: StatSite, _ value: String) {
        handles[site] = value
        saveHandles()
    }

    var filledSites: [StatSite] {
        StatSite.allCases.filter { !handle($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var statsSites: [StatSite] {
        StatSite.allCases.filter { (entries[$0]?.solved ?? -1) > 0 }
    }

    var totalSolved: Int {
        statsSites.reduce(0) { $0 + (entries[$1]?.solved ?? 0) }
    }

    func query(_ site: StatSite) async {
        let key = handle(site).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            entries[site] = StatEntry(error: "请先填写用户名")
            return
        }
        loading.insert(site)
        do {
            let snap = try await StatsService.fetch(site, handle: key)
            entries[site] = StatEntry(solved: snap.solved,
                                      rating: snap.rating,
                                      extra: snap.extra,
                                      updatedAt: Date(),
                                      error: nil)
        } catch {
            var entry = entries[site] ?? StatEntry()
            entry.error = error.localizedDescription
            entry.updatedAt = Date()
            entries[site] = entry
        }
        loading.remove(site)
        saveEntries()
    }

    func queryAll() async {
        for site in filledSites {
            await query(site)
        }
    }

    func clearAll() {
        handles = [:]
        entries = [:]
        loading = []
        saveHandles()
        saveEntries()
    }

    // MARK: - 持久化

    private func load() {
        if let data = defaults.data(forKey: handlesKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            handles = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let site = StatSite(rawValue: key) else { return nil }
                return (site, value)
            })
        }
        if let data = defaults.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([String: StatEntry].self, from: data) {
            entries = Dictionary(uniqueKeysWithValues: decoded.compactMap { key, value in
                guard let site = StatSite(rawValue: key) else { return nil }
                return (site, value)
            })
        }
    }

    private func saveHandles() {
        let raw = Dictionary(uniqueKeysWithValues: handles.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            defaults.set(data, forKey: handlesKey)
        }
    }

    private func saveEntries() {
        let raw = Dictionary(uniqueKeysWithValues: entries.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            defaults.set(data, forKey: entriesKey)
        }
    }
}