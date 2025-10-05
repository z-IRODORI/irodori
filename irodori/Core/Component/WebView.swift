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
    // WebViewProxyパターンを参考に、外部からWebViewを操作するための仕組み
    let webViewStore: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
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

        init(_ parent: WebView) {
            self.parent = parent
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
}

// MARK: - WebView Container

struct WebViewContainer: View {
    let url: URL
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var webViewStore = WebViewStore()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Header()
                .padding()
                .background(Color(UIColor.systemBackground))

            WebView(
                url: url,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                isLoading: $isLoading,
                webViewStore: webViewStore
            )
        }
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                    .background(Color(UIColor.systemBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func Header() -> some View {
        HStack {
            // Close
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            }

            Spacer()

            // Title
            Text(url.host ?? "")
                .font(.headline)

            Spacer()

            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: {
                    webViewStore.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(canGoBack ? .primary : .gray)
                }
                .disabled(!canGoBack)

                Button(action: {
                    webViewStore.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(canGoForward ? .primary : .gray)
                }
                .disabled(!canGoForward)

                // Reload
                Button(action: {
                    webViewStore.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(isLoading ? .gray : .primary)
                }
                .disabled(isLoading)
            }
        }
    }
}

#Preview {
    WebViewContainer(url: .init(string: "https://google.com")!)
}
