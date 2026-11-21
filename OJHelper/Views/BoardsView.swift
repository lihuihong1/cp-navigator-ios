import SwiftUI

struct BoardInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let url: URL
}

struct BoardsView: View {
    private let boards: [BoardInfo] = [
        BoardInfo(id: "xcpcio",
                  title: "XCPCIO 榜单",
                  subtitle: "ICPC / CCPC 实时榜与历史榜",
                  url: URL(string: "https://board.xcpcio.com/")!),
        BoardInfo(id: "rankland",
                  title: "RankLand",
                  subtitle: "400+ 赛事榜单合集",
                  url: URL(string: "https://rl.algoux.cn")!),
        BoardInfo(id: "iccpc",
                  title: "CCPC 外榜",
                  subtitle: "ICPC / CCPC 校外榜单（Outrank）",
                  url: URL(string: "https://rank.iccpc.cn/")!),
        BoardInfo(id: "cpcfinder",
                  title: "CPC Finder",
                  subtitle: "程序设计竞赛选手成绩查询",
                  url: URL(string: "https://cpcfinder.com/")!)
    ]

    @State private var opened: BoardInfo?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("榜单")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("ICPC / CCPC 等赛事榜单 · 应用内打开")
                        .font(.footnote)
                        .foregroundStyle(Theme.sub)
                }

                VStack(spacing: 10) {
                    ForEach(boards) { board in
                        Button {
                            opened = board
                        } label: {
                            card(board)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("XCPCIO 单场榜单较重，慢时可点右上角「浏览器」。")
                    .font(.footnote)
                    .foregroundStyle(Theme.sub)
                    .padding(.horizontal, 4)
            }
            .padding(16)
        }
        .background(Theme.bg.ignoresSafeArea())
        .fullScreenCover(item: $opened) { board in
            BoardPage(board: board)
        }
    }

    private func card(_ board: BoardInfo) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(board.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(board.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.sub.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack { BoardsView() }
}