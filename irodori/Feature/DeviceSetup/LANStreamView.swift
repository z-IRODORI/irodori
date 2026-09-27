//
//  LANStreamView.swift
//  irodori
//
//  玄関カメラが LAN 内に配信する MJPEG ページ (http://<ラズパイ>:8080/?t=…) を WebView で表示する。
//  同じ Wi-Fi にいるときだけ届く。読み込みに失敗したら onFailure を呼び、呼び出し側は
//  クラウド経由のプレビューに切り替える。
//  ページ側はフレームの縦横 (回転で変わる) を "frame" メッセージで知らせてくるので、
//  onFrameSize で受けて表示枠を映像と同じ比率にする。
//

import SwiftUI
import WebKit

struct LANStreamView: UIViewRepresentable {
    let url: URL
    var onFailure: () -> Void
    /// 映像 1 フレームの大きさ (px)。回転が変わると再度呼ばれる
    var onFrameSize: (CGSize) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure, onFrameSize: onFrameSize) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // ページ → iOS: フレームの縦横。Coordinator を直接登録すると WKUserContentController が
        // 強参照して解放されないため、弱参照のプロキシを挟む
        config.userContentController.add(WeakScriptMessageHandler(context.coordinator), name: "frame")
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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFrameSize = onFrameSize
        context.coordinator.onFailure = onFailure
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelWatchdog()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "frame")
        uiView.stopLoading()
        uiView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onFailure: () -> Void
        var onFrameSize: (CGSize) -> Void
        private var watchdog: Task<Void, Never>?
        private var loaded = false

        init(onFailure: @escaping () -> Void, onFrameSize: @escaping (CGSize) -> Void) {
            self.onFailure = onFailure
            self.onFrameSize = onFrameSize
        }

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

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "frame",
                  let body = message.body as? [String: Any],
                  let w = (body["w"] as? NSNumber)?.doubleValue,
                  let h = (body["h"] as? NSNumber)?.doubleValue,
                  w > 0, h > 0 else { return }
            onFrameSize(CGSize(width: w, height: h))
        }
    }

    /// WKUserContentController の強参照を切るためのプロキシ
    private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var target: WKScriptMessageHandler?
        init(_ target: WKScriptMessageHandler) { self.target = target }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            target?.userContentController(userContentController, didReceive: message)
        }
    }
}
