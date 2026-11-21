import SwiftUI

struct ContestListView: View {
    @ObservedObject var store: ContestStore
    @ObservedObject var notifier: NotificationManager

    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.grouped) { group in
                    Section(group.day) {
                        ForEach(group.items) { contest in
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("比赛")
            .refreshable {
                await notifier.refresh()
            }
            .task {
                await notifier.refresh()
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
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