import SwiftUI
import WebKit

/// 登录用的浏览器面板。
///
/// macOS 版把授权页交给系统浏览器，App 在 127.0.0.1:42681 等回调；iPadOS 上如果切到 Safari，
/// App 会被挂起、监听收不到回调，所以这里把浏览器搬进 App 内部：授权页、官网中转、本机回调页
/// 全在同一个 WKWebView 里走完，进程始终在前台。
struct PadAuthWebView: View {
    @Environment(AppModel.self) private var model
    let url: URL
    let onClose: () -> Void

    @State private var isLoading = true
    @State private var pageTitle = "华为账号授权"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.line)
            ZStack(alignment: .top) {
                WebViewRepresentable(url: url, isLoading: $isLoading, title: $pageTitle)
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
                        .padding(.top, 12)
                }
            }
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandLogo(size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(pageTitle)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("授权完成后这一步会自动继续，页面会显示同步进度")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.subtext)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("取消") {
                model.cancelSignIn()
                onClose()
            }
            .buttonStyle(.themed)
            Button {
                Platform.open(url)
            } label: {
                Image(systemName: "safari")
            }
            .buttonStyle(.themed)
            .help("在 Safari 中打开")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.panel)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var title: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // 华为账号授权页的深色样式不完整：标题、正文用深灰，压在深色底上几乎看不见
        // （实测深色下「华为账号登录」整块糊掉，二维码卡片反而还是白的）。
        // 这类第三方登录页一律强制浅色，网页的 prefers-color-scheme 也跟着变成 light；
        // 外层面板的标题栏仍走主题色，所以深色模式下界面不会割裂。
        webView.overrideUserInterfaceStyle = .light
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.underPageBackgroundColor = .white
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 只在外部换了 URL 时重新加载，避免刷新时打断用户操作。
        if webView.url == nil, !webView.isLoading {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            if let title = webView.title, !title.isEmpty {
                parent.title = title
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
