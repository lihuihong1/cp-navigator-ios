import UIKit
import SwiftUI

/// 收藏页：只读本地，不发网络请求。
struct FavoritesView: View {
    @EnvironmentObject private var store: ContestStore
    @EnvironmentObject private var notify: NotificationManager

    @State private var openTarget: Contest?
    @State private var calendarTarget: Contest?
    @State private var alertMessage: String?
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Line()
            ScrollView {
                VStack(spacing: 10) {
                    if store.favorites.isEmpty {
                        emptyCard
                    } else {
                        listCard
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { toastView }
        .sheet(item: $calendarTarget) { contest in
            CalendarSheet(contest: contest)
        }
        .alert("访问比赛页面？", isPresented: openAlertBinding, presenting: openTarget) { contest in
            Button("取消", role: .cancel) {}
            Button("访问") {
                if let url = contest.url {
                    UIApplication.shared.open(url)
                }
            }
        } message: { contest in
            Text("\(contest.title)\n\n\(contest.url?.absoluteString ?? "")")
        }
        .alert("无法添加日历", isPresented: messageAlertBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("收藏")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("共 \(store.favorites.count) 场 · 只保存在本机")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Theme.card)
    }

    private var emptyCard: some View {
        VStack(spacing: 4) {
            Text("还没有收藏的比赛")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("在比赛列表点右侧的 ☆ 即可收藏")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .card()
    }

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(store.favorites) { contest in
                if contest.id != store.favorites.first?.id {
                    Line().padding(.horizontal, 14)
                }
                row(contest)
            }
            Spacer().frame(height: 6)
        }
        .card()
    }

    private func row(_ contest: Contest) -> some View {
        ContestRow(
            contest: contest,
            dateMode: false,
            showLogo: true,
            isFavorite: store.isFavorite(contest),
            reminderLead: notify.lead(for: contest),
            onOpen: { openTarget = contest },
            onToggleFavorite: {
                store.toggleFavorite(contest)
                showToast("已取消收藏")
            },
            onSetReminder: { lead in setReminder(contest, lead: lead) },
            onAddCalendar: { addToCalendar(contest) }
        )
        .padding(.leading, 14)
        .padding(.trailing, 10)
    }

    private func setReminder(_ contest: Contest, lead: Int?) {
        Task {
            if let lead {
                let ok = await notify.schedule(contest, lead: lead)
                showToast(ok ? (lead == 0 ? "已设置：比赛开始时提醒" : "已设置：提前 \(lead) 分钟提醒") : (notify.lastError ?? "设置失败"))
            } else {
                await notify.cancel(contest)
                showToast("已关闭提醒")
            }
        }
    }

    private func addToCalendar(_ contest: Contest) {
        let now = Date()
        if contest.end <= now {
            showToast("比赛已结束，无法添加日历")
            return
        }
        if contest.start <= now {
            showToast("比赛已开始，无法添加日历")
            return
        }
        Task {
            switch await CalendarService.shared.ensureAccess() {
            case .granted:
                calendarTarget = contest
            case .denied:
                alertMessage = "没有日历写入权限。请在「设置 → 隐私与安全性 → 日历」中允许 OJ 助手添加事件。"
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            if toast == text { toast = nil }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.78))
                .clipShape(Capsule())
                .padding(.bottom, 24)
        }
    }

    private var openAlertBinding: Binding<Bool> {
        Binding(get: { openTarget != nil }, set: { if !$0 { openTarget = nil } })
    }

    private var messageAlertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }
}