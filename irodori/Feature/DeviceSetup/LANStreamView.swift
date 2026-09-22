//
//  LANStreamView.swift
//  irodori
//
//  玄関カメラが LAN 内に配信する MJPEG ページ (http://<ラズパイ>:8080/?t=…) を WebView で表示する。
//  同じ Wi-Fi にいるときだけ届く。読み込みに失敗したら onFailure を呼び、呼び出し側は
//  クラウド経由のプレビューに切り替える。
//

import SwiftUI
import WebKit

struct LANStreamView: UIViewRepresentable {
    let url: URL
    var onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.isOpaque = false
        web.backgroundColor = .black
        web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4))
        context.coordinator.startWatchdog()
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelWatchdog()
        uiView.stopLoading()
        uiView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onFailure: () -> Void
        private var watchdog: Task<Void, Never>?
        private var loaded = false

        init(onFailure: @escaping () -> Void) { self.onFailure = onFailure }

        /// 4 秒以内にページが開かなければ LAN 不達とみなす
        func startWatchdog() {
            watchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(4))
                guard let self, !Task.isCancelled, !self.loaded else { return }
                await MainActor.run { self.onFailure() }
            }
        }

        func cancelWatchdog() { watchdog?.cancel() }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            cancelWatchdog()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            cancelWatchdog()
            onFailure()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            cancelWatchdog()
            onFailure()
        }
    }
}
