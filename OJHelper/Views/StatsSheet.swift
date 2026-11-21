import SwiftUI
import Charts

struct StatsSheet: View {
    @EnvironmentObject private var store: StatsStore
    @Environment(\.dismiss) private var dismiss

    private struct Slice: Identifiable {
        let site: StatSite
        let value: Int
        var id: String { site.rawValue }
    }

    private var slices: [Slice] {
        store.statsSites.map { site in
            Slice(site: site, value: store.entries[site]?.solved ?? 0)
        }
    }

    private var total: Int { store.totalSolved }

    var body: some View {
        NavigationStack {
            ScrollView {
                if slices.isEmpty {
                    VStack(spacing: 8) {
                        Text("暂无数据")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("先在上面查一次各站的解题数，再回来看统计。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("总计：\(total) 题")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)

                        Chart(slices) { slice in
                            SectorMark(angle: .value("题数", slice.value),
                                       innerRadius: .ratio(0),
                                       angularInset: 1.5)
                                .foregroundStyle(slice.site.color)
                        }
                        .frame(height: 236)
                        .padding(.vertical, 4)

                        let columns = [GridItem(.flexible(), alignment: .leading),
                                       GridItem(.flexible(), alignment: .leading)]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(slices) { slice in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(slice.site.color)
                                        .frame(width: 8, height: 8)
                                    Text("\(slice.site.name) \(slice.value) · \(percentText(slice))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.sub)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("题解统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func percentText(_ slice: Slice) -> String {
        let total = Double(self.total)
        guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", Double(slice.value) / total * 100)
    }
}

#Preview {
    StatsSheet()
        .environmentObject(StatsStore())
}