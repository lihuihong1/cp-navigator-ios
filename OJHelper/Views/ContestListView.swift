import SwiftUI

struct ContestListView: View {
    @ObservedObject var store: ContestStore
    @ObservedObject var notifier: NotificationManager

    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            contestList
                .navigationTitle("比赛")
                .alert("提示", isPresented: showingAlert) {
                    Button("好", role: .cancel) { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private var contestList: some View {
        List {
            sections
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await notifier.refresh()
        }
        .task {
            await notifier.refresh()
        }
    }

    private var sections: some View {
        ForEach(store.grouped) { group in
            Section(group.day) {
                ForEach(group.items) { contest in
                    row(for: contest)
                }
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