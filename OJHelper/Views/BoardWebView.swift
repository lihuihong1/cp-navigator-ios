import SwiftUI
import UIKit
import WebKit

final class BoardWebModel: NSObject, ObservableObject {
    @Published var progress: Double = 0
    @Published var banner: Banner?
    @Published var currentURL: URL?

    struct Banner: Equatable {
        enum Kind { case slow, error }
        let kind: Kind
        let text: String
    }

    weak var webView: WKWebView?
    private var slowWork: DispatchWorkItem?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: [.new], context: nil)
    }

    func detach() {
        guard let webView else { return }
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            progress = webView?.estimatedProgress ?? 0
            if progress >= 1 { progress = 1 }
        } else if keyPath == #keyPath(WKWebView.url) {
            currentURL = webView?.url
        }
    }

    func didStartLoading() {
        progress = 0
        banner = nil
        slowWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let webView = self.webView, webView.isLoading else { return }
            self.banner = Banner(kind: .slow,
                                 text: "页面较大，仍在加载…  点右上角「浏览器」可改用系统浏览器打开")
        }
        slowWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: work)
    }

    func didFinishLoading() {
        slowWork?.cancel()
        progress = 1
        banner = nil
    }

    func didFail(_ error: Error) {
        slowWork?.cancel()
        progress = 0
        let ns = error as NSError
        // 取消（-999）不算错误
        guard ns.code != NSURLErrorCancelled else { return }
        let reason = ns.localizedDescription
        banner = Banner(kind: .error, text: "页面加载失败（\(reason)）  可用右上角「浏览器」打开")
    }

    func goBackOrNil() -> Bool {
        guard let webView, webView.canGoBack else { return false }
        webView.goBack()
        return true
    }
}

struct BoardWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let model: BoardWebModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "OjHelper/1.0"
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        model.attach(web)
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.model.detach()
        uiView.stopLoading()
        uiView.loadHTMLString("", baseURL: nil)
        uiView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: BoardWebModel
        init(model: BoardWebModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.didStartLoading()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.currentURL = webView.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.didFinishLoading()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.didFail(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            model.didFail(error)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
    }
}

struct BoardPage: View {
    let board: BoardInfo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BoardWebModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                BoardWebViewRepresentable(url: board.url, model: model)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    if model.progress > 0 && model.progress < 1 {
                        ProgressView(value: model.progress)
                            .progressViewStyle(.linear)
                            .tint(Theme.accent)
                    }
                    if let banner = model.banner {
                        bannerView(banner)
                    }
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle(board.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("返回") {
                        if !model.goBackOrNil() { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("浏览器") {
                        UIApplication.shared.open(model.currentURL ?? board.url)
                    }
                }
            }
        }
    }

    private func bannerView(_ banner: BoardWebModel.Banner) -> some View {
        let amber = Color(hex: 0xFFF7E0)
        let amberText = Color(hex: 0x92400E)
        let red = Color(hex: 0xFEE2E2)
        let redText = Color(hex: 0x991B1B)
        let isError = banner.kind == .error
        return Text(banner.text)
            .font(.system(size: 12))
            .foregroundStyle(isError ? redText : amberText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isError ? red : amber)
    }
}

#Preview {
    BoardPage(board: BoardInfo(id: "rankland", title: "RankLand",
                               subtitle: "400+ 赛事榜单合集",
                               url: URL(string: "https://rl.algoux.cn")!))
}