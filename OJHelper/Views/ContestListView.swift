import SwiftUI

struct ContestListView: View {
    @ObservedObject var store: ContestStore
    @ObservedObject var notifier: NotificationManager

    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("比赛")
                .toolbar { toolbar }
                .refreshable { await store.refresh() }
                .task { await store.refreshIfStale() }
                .alert("提示", isPresented: showingAlert) {
                    Button("好", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.contests.isEmpty {
            if store.isLoading {
                ProgressView("正在拉取比赛…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        } else {
            contestList
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有比赛", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text(store.siteErrors.isEmpty ? "下拉刷新试试。" : "没能从各站点取到数据，检查网络后再试。")
        } actions: {
            Button("重新获取") {
                Task { await store.refresh() }
            }
        }
    }

    private var contestList: some View {
        List {
            ForEach(store.grouped, id: \.id) { group in
                section(for: group)
            }
            footer
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(store.isLoading)
            .accessibilityLabel("刷新")
        }
    }

    @ViewBuilder
    private func section(for group: DayGroup) -> some View {
        Section {
            ForEach(group.items, id: \.id) { contest in
                row(for: contest)
            }
        } header: {
            Text(group.day)
        }
    }

    @ViewBuilder
    private var footer: some View {
        Section {
            if store.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在刷新…")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else if let updated = store.lastUpdated {
                Text("更新于 \(Contest.hm(updated))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if !store.siteErrors.isEmpty {
                Text("未能获取：\(store.failedSiteNames)。下拉刷新可重试。")
            }
        }
    }

    private func row(for contest: Contest) -> some View {
        ContestRow(
            contest: contest,
            isReminded: notifier.isReminded(contest),
            onSetReminder: { lead in
                Task { await set(contest, lead) }
            },
            onCancel: {
                Task { await notifier.cancel(contest) }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = contest.url {
                openURL(url)
            }
        }
    }

    private var showingAlert: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue { errorMessage = nil }
            }
        )
    }

    private func set(_ contest: Contest, _ lead: Int) async {
        let ok = await notifier.schedule(contest, lead: lead)
        if !ok {
            errorMessage = notifier.lastError ?? "设置失败"
        }
    }
}

#Preview {
    ContestListView(store: ContestStore(), notifier: NotificationManager.shared)
}