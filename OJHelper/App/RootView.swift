import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = ContestStore()
    @StateObject private var notifier = NotificationManager.shared

    var body: some View {
        TabView {
            NavigationStack {
                ContestListView()
            }
            .tabItem { Label("比赛", systemImage: "list.bullet") }

            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label("收藏", systemImage: "star") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Theme.accent)
        .environmentObject(store)
        .environmentObject(notifier)
        .task {
            await NotificationManager.shared.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await notifier.refresh() }
            }
        }
    }
}

#Preview {
    RootView()
}