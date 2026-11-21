import UIKit
import SwiftUI

/// 比赛页：进入不自动查询，点「查询」才联网；结果只在内存里。
struct ContestListView: View {
    @EnvironmentObject private var store: ContestStore
    @EnvironmentObject private var notify: NotificationManager

    @State private var showSources = false
    @State private var collapsed: Set<String> = []
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
                    content
                }
                .padding(12)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { toastView }
        .sheet(isPresented: $showSources) {
            SourcesSheet()
        }
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

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("近期比赛")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                queryButton
            }
            HStack(spacing: 8) {
                modeChip("按平台", on: !store.dateMode) { store.dateMode = false }
                modeChip("按日期", on: store.dateMode) { store.dateMode = true }
                Spacer()
                sourcesButton
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Theme.card)
    }

    private var queryButton: some View {
        Button {
            Task { await store.query() }
        } label: {
            Text(store.isQuerying ? "查询中" : "查询")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(store.isQuerying ? Theme.sub : Theme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(store.isQuerying ? Theme.line : Theme.accent, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(store.isQuerying)
    }

    private func modeChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundStyle(on ? Theme.accent : Theme.sub)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(on ? Theme.accent.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sourcesButton: some View {
        Button {
            showSources = true
        } label: {
            Text("平台 \(store.enabled.count)/\(OJ.allCases.count)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        if let at = store.lastQueriedAt {
            let fail = store.failedCount
            let failText = fail > 0 ? "（\(fail) 个源失败）" : ""
            return "共 \(store.totalCount) 场\(failText) · \(Contest.windowText()) · \(Contest.formatter("HH:mm:ss").string(from: at)) 查询"
        }
        return "\(Contest.windowText()) · \(store.sourceNames)"
    }

    // MARK: - 正文

    @ViewBuilder
    private var content: some View {
        if store.isQuerying {
            ForEach(store.sites) { oj in
                skeleton(oj)
            }
        } else if store.results == nil {
            introCard
        } else {
            if let tip = staleTip {
                Text(tip)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.warn)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .card()
            }
            if store.dateMode {
                dateSections
            } else {
                ojSections
            }
            note
        }
    }

    private var introCard: some View {
        VStack(spacing: 6) {
            Text("点右上角「查询」")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("会实时访问 \(store.sourceNames) 的公开页面，\n列出 \(Contest.windowText()) 之间未开始和正在进行的比赛。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
            Text("查询结果不落盘，退出应用即清空；收藏另存本地。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.sub)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .card()
    }

    private func skeleton(_ oj: OJ) -> some View {
        HStack(spacing: 8) {
            LogoView(oj: oj, size: 18)
            Text("正在查询…")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .card()
    }

    // MARK: - 按平台

    private var ojSections: some View {
        ForEach(store.results ?? []) { result in
            ojSection(result)
        }
    }

    private func ojSection(_ result: SiteResult) -> some View {
        let key = "oj:\(result.oj.rawValue)"
        let open = !collapsed.contains(key)
        return VStack(spacing: 0) {
            Button {
                toggle(key)
            } label: {
                HStack(spacing: 8) {
                    LogoView(oj: result.oj, size: 22)
                    Text(result.oj.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(result.failed ? "失败" : "\(result.list.count) 场")
                        .font(.system(size: 12))
                        .foregroundStyle(result.failed ? Theme.red : Theme.sub)
                    Text(open ? "▾" : "▸")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            Line()

            if open {
                if result.failed {
                    Text(errorText(result.error))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else if result.list.isEmpty {
                    Text("7 天内没有已公布的比赛")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    ForEach(result.list) { contest in
                        if contest.id != result.list.first?.id {
                            Line().padding(.horizontal, 14)
                        }
                        row(contest, dateMode: false, showLogo: false)
                    }
                    Spacer().frame(height: 6)
                }
            }
        }
        .card()
    }

    // MARK: - 按日期

    private var dateSections: some View {
        VStack(spacing: 10) {
            ForEach(store.dayBuckets()) { bucket in
                daySection(bucket)
            }
            if store.failedCount > 0 {
                failedCard
            }
        }
    }

    private func daySection(_ bucket: DayBucket) -> some View {
        let key = "day:\(bucket.day.timeIntervalSince1970)"
        let open = !collapsed.contains(key)
        let isToday = Contest.dayDiff(bucket.day) == 0
        return VStack(spacing: 0) {
            Button {
                toggle(key)
            } label: {
                HStack(spacing: 8) {
                    Text(Contest.dayFull(bucket.day))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(bucket.list.count) 场")
                        .font(.system(size: 12))
                        .foregroundStyle(bucket.list.isEmpty ? Theme.sub : (isToday ? Theme.accent : Theme.sub))
                    Text(open ? "▾" : "▸")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            Line()

            if open {
                if bucket.list.isEmpty {
                    Text("没有比赛")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    ForEach(bucket.list) { contest in
                        if contest.id != bucket.list.first?.id {
                            Line().padding(.horizontal, 14)
                        }
                        row(contest, dateMode: true, showLogo: true)
                    }
                    Spacer().frame(height: 6)
                }
            }
        }
        .card()
    }

    private var failedCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("以下平台没查到")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.red)
            ForEach(store.results?.filter(\.failed) ?? []) { result in
                Text("\(result.oj.name) · \(errorText(result.error))")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }

    private var note: some View {
        Text("数据实时抓取自各站公开页面；站点改版可能导致某一路失效，此时可按「查询」重试。")
            .font(.system(size: 11))
            .foregroundStyle(Theme.sub)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, 16)
    }

    // MARK: - 行

    private func row(_ contest: Contest, dateMode: Bool, showLogo: Bool) -> some View {
        ContestRow(
            contest: contest,
            dateMode: dateMode,
            showLogo: showLogo,
            isFavorite: store.isFavorite(contest),
            reminderLead: notify.lead(for: contest),
            onOpen: { openTarget = contest },
            onToggleFavorite: { toggleFavorite(contest) },
            onSetReminder: { lead in setReminder(contest, lead: lead) },
            onAddCalendar: { addToCalendar(contest) }
        )
        .padding(.leading, 14)
        .padding(.trailing, 10)
    }

    // MARK: - 动作

    private func toggle(_ key: String) {
        if collapsed.contains(key) {
            collapsed.remove(key)
        } else {
            collapsed.insert(key)
        }
    }

    private func toggleFavorite(_ contest: Contest) {
        let added = store.toggleFavorite(contest)
        showToast(added ? "已收藏" : "已取消收藏")
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

    // MARK: - 杂项

    private var staleTip: String? {
        guard let at = store.lastQueriedAt else { return nil }
        let minutes = Int(Date().timeIntervalSince(at) / 60)
        guard minutes >= 15 else { return nil }
        let when = minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时"
        return "这是 \(Contest.formatter("HH:mm:ss").string(from: at)) 的快照，已过 \(when)，可能已经过期，点「查询」更新。"
    }

    private func errorText(_ error: Error?) -> String {
        guard let error else { return "失败" }
        return error.localizedDescription
    }

    private var openAlertBinding: Binding<Bool> {
        Binding(
            get: { openTarget != nil },
            set: { if !$0 { openTarget = nil } }
        )
    }

    private var messageAlertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }
}