//
//  ImageSearchScraper.swift
//  irodori
//
//  キーワードから画像候補URLを取得する (バックエンド不要・iOS完結)。
//
//  検索結果のWeb画面はユーザーに見せず、オフスクリーンの WKWebView で
//  画像検索結果ページを裏で読み込み、evaluateJavaScript で <img> の実URLだけを
//  抽出して返す。取得したURLはネイティブのグリッドで表示する。
//
//  ⚠️ 検索エンジンの結果を自動抽出する行為は各社の利用規約で制限されることが多く、
//  取得画像は著作権物である。本アプリでは「ユーザーの非公開クローゼットに登録する」
//  用途に限定し、堅牢性・規約順守を最優先する場合は公式の画像検索APIが本筋である。
//

import UIKit
import WebKit

protocol ImageSearchScraping {
    /// キーワード (と性別) で画像候補URLを最大 limit 件返す。
    func searchImageURLs(keyword: String, gender: String?, limit: Int) async throws -> [URL]
}

enum ImageSearchError: LocalizedError {
    case invalidKeyword
    case loadFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidKeyword: return "検索キーワードが正しくありません"
        case .loadFailed: return "検索に失敗しました。通信環境をご確認ください"
        case .noResults: return "画像が見つかりませんでした。別のキーワードをお試しください"
        }
    }
}

@MainActor
final class ImageSearchScraper: ImageSearchScraping {

    // 進行中の1件のみを保持する (連続検索時は前回を破棄)
    private var continuation: CheckedContinuation<[URL], Error>?
    private var webView: WKWebView?
    private var coordinator: Coordinator?
    private var timeoutTask: Task<Void, Never>?
    private var finished = false
    private var limit = 15

    func searchImageURLs(keyword: String, gender: String?, limit: Int) async throws -> [URL] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImageSearchError.invalidKeyword }

        let query = [trimmed, Self.genderKeyword(gender)]
            .compactMap { $0 }
            .joined(separator: " ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://search.yahoo.co.jp/image/search?p=\(encoded)") else {
            throw ImageSearchError.invalidKeyword
        }

        // 前回の実行が残っていれば破棄
        cleanup()
        self.limit = max(1, limit)
        self.finished = false

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let coordinator = Coordinator()
            coordinator.onFinish = { [weak self] finishedWebView in
                // WebKit のデリゲートはメインスレッドで呼ばれる。抽出は非同期で行う。
                Task { @MainActor in
                    await self?.extractAndResume(from: finishedWebView)
                }
            }
            coordinator.onFail = { [weak self] in
                Task { @MainActor in
                    self?.resume(.failure(ImageSearchError.loadFailed))
                }
            }
            self.coordinator = coordinator

            // 遅延ロード画像もある程度描画させるため、縦に長いフレームで生成する。
            // ビュー階層には載せない (ユーザーには見せない)。
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 414, height: 3000))
            webView.navigationDelegate = coordinator
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            self.webView = webView
            webView.load(URLRequest(url: url))

            // ハング対策のタイムアウト
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard let self, !self.finished else { return }
                self.resume(.failure(ImageSearchError.loadFailed))
            }
        }
    }

    // MARK: - 抽出

    private func extractAndResume(from webView: WKWebView) async {
        guard !finished, webView === self.webView else { return }

        // 遅延ロードの完了を少し待ってから、下方向へスクロールして追加画像を読ませる
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        _ = try? await webView.evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight);")
        try? await Task.sleep(nanoseconds: 700_000_000)

        guard !finished else { return }

        let js = """
        (function() {
          var out = [];
          var seen = {};
          var imgs = document.getElementsByTagName('img');
          for (var i = 0; i < imgs.length; i++) {
            var el = imgs[i];
            var s = el.currentSrc || el.src || '';
            if (s.lastIndexOf('http', 0) !== 0) continue;   // http(s) 以外 (data: 等) は除外
            if (s.indexOf('.gif') > -1) continue;            // スペーサー等
            var w = el.naturalWidth || el.clientWidth || 0;
            if (w > 0 && w < 60) continue;                   // アイコン等の極小画像は除外
            if (seen[s]) continue;
            seen[s] = true;
            out.push(s);
          }
          return out;
        })();
        """

        let jsResult: Any?
        do {
            jsResult = try await webView.evaluateJavaScript(js)
        } catch {
            jsResult = nil
        }
        let raw = (jsResult as? [String]) ?? []

        var seen = Set<String>()
        var urls: [URL] = []
        for string in raw {
            guard seen.insert(string).inserted, let url = URL(string: string) else { continue }
            urls.append(url)
            if urls.count >= limit { break }
        }

        if urls.isEmpty {
            resume(.failure(ImageSearchError.noResults))
        } else {
            resume(.success(urls))
        }
    }

    // MARK: - 完了処理

    private func resume(_ result: Result<[URL], Error>) {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        timeoutTask = nil

        let continuation = self.continuation
        self.continuation = nil

        switch result {
        case .success(let urls): continuation?.resume(returning: urls)
        case .failure(let error): continuation?.resume(throwing: error)
        }
        cleanup()
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        coordinator = nil
    }

    private static func genderKeyword(_ gender: String?) -> String? {
        switch gender {
        case "men": return "メンズ"
        case "women": return "レディース"
        default: return nil
        }
    }

    // MARK: - Navigation Delegate (非分離の薄いコーディネーター)

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFinish: ((WKWebView) -> Void)?
        var onFail: (() -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinish?(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFail?()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFail?()
        }
    }
}

// MARK: - Mock

final class MockImageSearchScraper: ImageSearchScraping {
    func searchImageURLs(keyword: String, gender: String?, limit: Int) async throws -> [URL] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return (0..<limit).compactMap { URL(string: "https://example.com/\(keyword)_\($0).jpg") }
    }
}
