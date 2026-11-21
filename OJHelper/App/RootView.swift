import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ContestStore()
    @ObservedObject private var notifier = NotificationManager.shared

    var body: some View {
        TabView {
            ContestListView(store: store, notifier: notifier)
                .tabItem { Label("比赛", systemImage: "list.bullet") }

            SettingsView(notifier: notifier)
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Color(red: 0.16, green: 0.55, blue: 0.52))
        .task {
            await NotificationManager.shared.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await notifier.refresh()
                    await store.refreshIfStale()
                }
            }
        }
    }
}

#Preview {
    RootView()
}