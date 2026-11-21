import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: StatsStore
    @EnvironmentObject private var contests: ContestStore
    @EnvironmentObject private var notify: NotificationManager

    @State private var showStats = false
    @State private var confirmClear = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Line()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(StatSite.allCases) { site in
                        siteCard(site)
                    }
                    aboutCard
                }
                .padding(12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showStats) {
            StatsSheet()
                .environmentObject(store)
        }
        .alert("清空本地数据？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { clearAll() }
        } message: {
            Text("会删除各站用户名、成绩、收藏与提醒记录，且不可恢复。")
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.bottom, 28)
                    .transition(.opacity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("我的")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                outlineButton("题解统计") { showStats = true }
                outlineButton("全部查询") { queryAll() }
            }
            Text("只需填各站公开的用户名 / id，不需要登录")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Theme.card)
    }

    private func outlineButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.accent.opacity(0.75), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func siteCard(_ site: StatSite) -> some View {
        let entry = store.entries[site]
        let isLoading = store.loading.contains(site)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                if let logo = site.logoName {
                    Image(logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Circle()
                        .fill(site.color.opacity(0.15))
                        .frame(width: 20, height: 20)
                        .overlay(Text(String(site.name.prefix(1)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(site.color))
                }
                Text(site.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                outlineButton("查询") { query(site) }
            }

            TextField(site.hint, text: handleBinding(site))
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if isLoading {
                Text("查询中…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            } else if let entry {
                if let err = entry.error, entry.solved < 0 {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.red)
                } else {
                    Text(resultText(entry))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(metaText(entry))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.sub)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("版本")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(version)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Line().padding(.horizontal, 14)

            Text("用户名与成绩只保存在本机，不云备份；卸载应用会清空。各站数据来自其公开页面，可能因站点改版失效。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
                .padding(14)

            Line().padding(.horizontal, 14)

            Button {
                confirmClear = true
            } label: {
                HStack {
                    Text("清空本地数据")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.red)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 数据

    private func handleBinding(_ site: StatSite) -> Binding<String> {
        Binding(get: { store.handle(site) },
                set: { store.setHandle(site, $0) })
    }

    private func query(_ site: StatSite) {
        Task { await store.query(site) }
    }

    private func queryAll() {
        guard !store.filledSites.isEmpty else {
            show("还没有填写任何用户名")
            return
        }
        Task { await store.queryAll() }
    }

    private func clearAll() {
        store.clearAll()
        contests.clearFavorites()
        Task {
            await notify.cancelAll()
            show("已清空本地数据")
        }
    }

    private func resultText(_ entry: StatEntry) -> String {
        let solved = entry.solved >= 0 ? "\(entry.solved)" : "—"
        let rating = entry.rating.map { String(format: "%.0f", $0) } ?? "—"
        return "解题 \(solved)　·　rating \(rating)"
    }

    private func metaText(_ entry: StatEntry) -> String {
        var parts: [String] = []
        if let at = entry.updatedAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "MM-dd HH:mm"
            f.timeZone = TimeZone(identifier: "Asia/Shanghai")
            parts.append("更新于 \(f.string(from: at))")
        }
        if let extra = entry.extra, !extra.isEmpty { parts.append(extra) }
        if let err = entry.error, !err.isEmpty { parts.append(err) }
        return parts.joined(separator: " · ")
    }

    private func show(_ text: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(StatsStore())
        .environmentObject(ContestStore())
        .environmentObject(NotificationManager.shared)
}