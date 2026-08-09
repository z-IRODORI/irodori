//
//  WebView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/05.
//

import SwiftUI
import WebKit

// MARK: - WebView Component

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    /// 表示中ページのタイトル (商品名など)。ヘッダーのタイトル表示に使う
    @Binding var pageTitle: String
    // WebViewProxyパターンを参考に、外部からWebViewを操作するための仕組み
    let webViewStore: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.observeTitle(of: webView)
        webView.load(URLRequest(url: url))

        // WebViewStoreに参照を保持
        webViewStore.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        private var titleObservation: NSKeyValueObservation?

        init(_ parent: WebView) {
            self.parent = parent
        }

        /// ページ内遷移 (SPA含む) でもヘッダーのタイトルが追従するよう KVO で監視する
        func observeTitle(of webView: WKWebView) {
            titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.parent.pageTitle = webView.title ?? ""
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

// MARK: - WebViewStore (WebUIのProxyパターンを簡略化)

/// WebViewの操作を管理するクラス
///
/// ## 設計意図
/// UIViewRepresentableの制約により、SwiftUIのViewから直接WKWebViewインスタンスを
/// 操作することができません。WebViewStoreはこの問題を解決するために、
/// WKWebViewへの参照を保持し、SwiftUIから安全に操作できるインターフェースを提供します。
///
/// ## 採用理由
/// - **責任の分離**: WebView（UI生成）とWebViewStore（操作）で責任を明確に分離
/// - **参照管理**: weak参照により循環参照を防ぎ、メモリリークを回避
/// - **拡張性**: 新しい操作メソッドを簡単に追加可能
/// - **SwiftUIパターン**: ScrollViewReaderなどと同様の、SwiftUIで一般的なProxyパターンを採用
///
/// ## 使用例
/// ```swift
/// struct ContentView: View {
///     @State private var webViewStore = WebViewStore()
///
///     var body: some View {
///         Button("Reload") {
///             webViewStore.reload()
///         }
///     }
/// }
/// ```
///
/// ## 参考
/// このパターンは[cybozu/WebUI](https://github.com/cybozu/WebUI)の
/// WebViewReader/WebViewProxyパターンを参考に、より簡潔に実装したものです。
class WebViewStore: ObservableObject {
    /// WKWebViewへの弱参照
    /// - Note: 弱参照により循環参照を防ぎ、WebViewが破棄された際は自動的にnilになる
    weak var webView: WKWebView?

    /// 現在のページを再読み込みする
    func reload() {
        webView?.reload()
    }

    /// 前のページに戻る
    func goBack() {
        webView?.goBack()
    }

    /// 次のページに進む
    func goForward() {
        webView?.goForward()
    }

    /// WebView が現在表示している URL (外部ブラウザで開く用)。未取得時は nil。
    var currentURL: URL? {
        webView?.url
    }
}

// MARK: - WebView Container

struct WebViewContainer: View {
    let url: URL
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var pageTitle = ""
    @State private var webViewStore = WebViewStore()
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    // Web ページの表示領域を最大化するため、上部はタイトル+閉じるの最小構成にし、
    // ナビゲーション操作 (戻る/進む/リロード/Safari) は片手で届く下部バーへ置く (Safari の文法)
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            WebView(
                url: url,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                webViewStore: webViewStore
            )
            .overlay(alignment: .center) {
                if isLoading {
                    ProgressView()
                }
            }

            Divider()
            bottomBar
        }
        .background(Color(UIColor.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("閉じる")

            // ページタイトル (商品名など)。取得できるまではホスト名を表示
            Text(pageTitle.isEmpty ? (url.host ?? "") : pageTitle)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)

            // タイトルを中央に保つための xmark と同幅のバランサー
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(UIColor.systemBackground))
    }

    private var bottomBar: some View {
        HStack {
            Button(action: { webViewStore.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(canGoBack ? .primary : Color.gray.opacity(0.4))
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)

            Button(action: { webViewStore.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(canGoForward ? .primary : Color.gray.opacity(0.4))
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoForward)

            Spacer()

            Button(action: { webViewStore.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isLoading ? Color.gray.opacity(0.4) : .primary)
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .disabled(isLoading)

            // ブラウザ(Safari)で開く: WebView 内で遷移した先があればその URL を優先
            Button(action: { openURL(webViewStore.currentURL ?? url) }) {
                Image(systemName: "safari")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("ブラウザで開く")
        }
        .padding(.horizontal, 8)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    WebViewContainer(url: .init(string: "https://google.com")!)
}
