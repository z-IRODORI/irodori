//
//  ImageSearchScraper.swift
//  irodori
//
//  キーワードから画像候補を取得する (バックエンド不要・iOS完結)。
//
//  検索結果のWeb画面はユーザーに見せず、オフスクリーンの WKWebView で
//  画像検索結果ページを裏で読み込み、evaluateJavaScript で各結果の
//  「原寸URL(murl)」と「サムネURL(turl)」を抽出して返す。
//  グリッド表示はサムネで軽快に、登録時は原寸を使って高画質にする。
//
//  高速化のため:
//   - WKContentRuleList で画像/CSS/フォント/メディアの読込をブロック
//     (欲しいのは結果HTMLだけ。サムネ描画は不要 → ページ読込が大幅に軽くなる)
//   - 固定スリープを廃し、抽出でき次第すぐ返すポーリング方式
//
//  ⚠️ 検索エンジンの結果を自動抽出する行為は各社の利用規約で制限されることが多く、
//  取得画像は著作権物である。本アプリでは「ユーザーの非公開クローゼットに登録する」
//  用途に限定する。堅牢性・規約順守を最優先する場合は公式の画像検索APIが本筋。
//

import UIKit
import WebKit

/// 検索結果の1件。グリッドは thumbnail、登録は original を使う。
struct SearchImageResult: Identifiable, Hashable {
    let id = UUID()
    let thumbnailURL: URL
    let originalURL: URL
}

protocol ImageSearchScraping {
    func search(keyword: String, gender: String?, limit: Int) async throws -> [SearchImageResult]
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

    private var continuation: CheckedContinuation<[SearchImageResult], Error>?
    private var webView: WKWebView?
    private var coordinator: Coordinator?
    private var pollTask: Task<Void, Never>?
    private var finished = false
    private var didFinishLoad = false
    private var didFailLoad = false
    private var limit = 15

    // 画像/CSS/フォント/メディアの読込をブロックするルール (一度だけコンパイルして再利用)
    private static var cachedBlockRules: WKContentRuleList?

    func search(keyword: String, gender: String?, limit: Int) async throws -> [SearchImageResult] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImageSearchError.invalidKeyword }

        let query = [trimmed, Self.genderKeyword(gender)]
            .compactMap { $0 }
            .joined(separator: " ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.bing.com/images/search?q=\(encoded)&form=HDRSC2") else {
            throw ImageSearchError.invalidKeyword
        }

        // 重いサブリソースを事前にブロック (継続に入る前に await)
        let blockRules = await Self.loadBlockRules()

        cleanup()
        self.limit = max(1, limit)
        self.finished = false
        self.didFinishLoad = false
        self.didFailLoad = false

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let coordinator = Coordinator()
            coordinator.onFinish = { [weak self] in
                Task { @MainActor in self?.didFinishLoad = true }
            }
            coordinator.onFail = { [weak self] in
                Task { @MainActor in self?.didFailLoad = true }
            }
            self.coordinator = coordinator

            let config = WKWebViewConfiguration()
            if let blockRules { config.userContentController.add(blockRules) }

            // ビュー階層には載せない (ユーザーには見せない)。iusc はHTMLに含まれるので描画は不要。
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), configuration: config)
            webView.navigationDelegate = coordinator
            // デスクトップ版Bing (a.iusc 構造) を得るためデスクトップUAにする
            webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
            self.webView = webView
            webView.load(URLRequest(url: url))

            startPolling()
        }
    }

    // MARK: - ポーリング抽出 (取得でき次第すぐ返す)

    private func startPolling() {
        pollTask = Task { @MainActor [weak self] in
            // 最大 ~8秒 (40 × 200ms)。ページ完了 or 十分な件数が取れたら即終了。
            for _ in 0..<40 {
                guard let self, !self.finished else { return }
                let results = await self.extract()
                if results.count >= self.limit || (self.didFinishLoad && !results.isEmpty) {
                    self.resume(.success(Array(results.prefix(self.limit))))
                    return
                }
                if self.didFailLoad && results.isEmpty {
                    self.resume(.failure(ImageSearchError.loadFailed))
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard let self, !self.finished else { return }
            let results = await self.extract()
            if results.isEmpty {
                self.resume(.failure(ImageSearchError.noResults))
            } else {
                self.resume(.success(Array(results.prefix(self.limit))))
            }
        }
    }

    private func extract() async -> [SearchImageResult] {
        guard let webView else { return [] }

        // Bing: a.iusc の m 属性JSON から murl(原寸)/turl(サムネ) を得る。
        // 取れない場合は img から (murl=turl) をフォールバック。
        let js = """
        (function() {
          var out = [];
          var seen = {};
          var anchors = document.querySelectorAll('a.iusc');
          for (var i = 0; i < anchors.length; i++) {
            var mv = anchors[i].getAttribute('m');
            if (!mv) continue;
            try {
              var o = JSON.parse(mv);
              var murl = o.murl || '';
              var turl = o.turl || '';
              if (murl.lastIndexOf('http', 0) !== 0) continue;
              if (seen[murl]) continue;
              seen[murl] = true;
              out.push({ murl: murl, turl: (turl.lastIndexOf('http', 0) === 0 ? turl : murl) });
            } catch (e) {}
          }
          if (out.length === 0) {
            var imgs = document.getElementsByTagName('img');
            for (var j = 0; j < imgs.length; j++) {
              var s = imgs[j].currentSrc || imgs[j].src || '';
              if (s.lastIndexOf('http', 0) !== 0) continue;
              if (s.indexOf('.gif') > -1) continue;
              var w = imgs[j].naturalWidth || imgs[j].clientWidth || 0;
              if (w > 0 && w < 60) continue;
              if (seen[s]) continue;
              seen[s] = true;
              out.push({ murl: s, turl: s });
            }
          }
          return out;
        })();
        """

        let jsResult: Any?
        do {
            jsResult = try await webView.evaluateJavaScript(js)
        } catch {
            return []
        }

        let rows = (jsResult as? [[String: Any]]) ?? []
        var seen = Set<String>()
        var results: [SearchImageResult] = []
        for row in rows {
            guard let murlString = row["murl"] as? String,
                  let original = URL(string: murlString),
                  seen.insert(murlString).inserted else { continue }
            let turlString = (row["turl"] as? String) ?? murlString
            let thumbnail = URL(string: turlString) ?? original
            results.append(SearchImageResult(thumbnailURL: thumbnail, originalURL: original))
        }
        return results
    }

    // MARK: - 完了処理

    private func resume(_ result: Result<[SearchImageResult], Error>) {
        guard !finished else { return }
        finished = true
        pollTask?.cancel()
        pollTask = nil

        let continuation = self.continuation
        self.continuation = nil

        switch result {
        case .success(let results): continuation?.resume(returning: results)
        case .failure(let error): continuation?.resume(throwing: error)
        }
        cleanup()
    }

    private func cleanup() {
        pollTask?.cancel()
        pollTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        coordinator = nil
    }

    // MARK: - リソースブロックのルール

    private static func loadBlockRules() async -> WKContentRuleList? {
        if let cached = cachedBlockRules { return cached }
        guard let store = WKContentRuleListStore.default() else { return nil }
        let json = """
        [{"trigger":{"url-filter":".*","resource-type":["image","style-sheet","font","media"]},"action":{"type":"block"}}]
        """
        let list: WKContentRuleList? = await withCheckedContinuation { continuation in
            store.compileContentRuleList(
                forIdentifier: "irodori-image-search-block",
                encodedContentRuleList: json
            ) { list, _ in
                continuation.resume(returning: list)
            }
        }
        if let list { cachedBlockRules = list }
        return list
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
        var onFinish: (() -> Void)?
        var onFail: (() -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onFinish?()
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
    func search(keyword: String, gender: String?, limit: Int) async throws -> [SearchImageResult] {
        try await Task.sleep(nanoseconds: 300_000_000)
        return (0..<limit).compactMap { index in
            guard let thumb = URL(string: "https://example.com/\(keyword)_\(index)_thumb.jpg"),
                  let original = URL(string: "https://example.com/\(keyword)_\(index).jpg") else { return nil }
            return SearchImageResult(thumbnailURL: thumb, originalURL: original)
        }
    }
}
