//
//  ItemImageReplaceViewModel.swift
//  irodori
//
//  撮影切り抜きのアイテム画像を、ネット検索で見つけた商品画像に差し替える。
//  検索は ImageSearchScraper (隠しWebView・バックエンド不要)、
//  保存は ItemImageEditViewModel と同じ「新規登録 → 旧アイテム削除」方式で、
//  サーバ無改修・既存の Storage / Firestore データ不変更のまま実現する。
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ItemImageReplaceViewModel {
    let item: ClosetItem

    var query: String
    var isSearching = false
    var results: [SearchImageResult] = []
    var errorMessage: String?
    /// 一度でも検索を実行したか (初期の空状態と「0件」を区別する)
    var hasSearched = false

    /// グリッドで選択中の候補 (下部の差し替えバーに反映)
    var selected: SearchImageResult?
    var isApplying = false

    private let scraper: ImageSearchScraping
    private let registerClient: BulkItemRegisterClientProtocol
    private let deleteClient: DeleteClosetItemClientProtocol

    // ImageSearchScraper は @MainActor のため、デフォルト引数(非分離で評価)では
    // 生成できない。nil を既定にし、@MainActor な init 本体で生成する。
    init(
        item: ClosetItem,
        scraper: ImageSearchScraping? = nil,
        registerClient: BulkItemRegisterClientProtocol = BulkItemRegisterClient(),
        deleteClient: DeleteClosetItemClientProtocol = DeleteClosetItemClient()
    ) {
        self.item = item
        self.query = Self.defaultQuery(for: item)
        self.scraper = scraper ?? ImageSearchScraper()
        self.registerClient = registerClient
        self.deleteClient = deleteClient
    }

    /// アイテム属性から初期検索ワードを組み立てる (例: "グレー スウェット")
    static func defaultQuery(for item: ClosetItem) -> String {
        let parts = [item.color, item.category]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? item.item_type : parts.joined(separator: " ")
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSearching else { return }

        isSearching = true
        errorMessage = nil
        results = []
        selected = nil
        hasSearched = true
        defer { isSearching = false }

        let gender = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        do {
            let found = try await scraper.search(keyword: trimmed, gender: gender, limit: 15)
            results = found
            if found.isEmpty {
                errorMessage = ImageSearchError.noResults.errorDescription
            }
        } catch {
            errorMessage = (error as? ImageSearchError)?.errorDescription ?? "検索に失敗しました"
        }
    }

    /// 選択中の候補で差し替える: DL → 端末内で背景除去/正方形化 → 新規登録 → 旧削除。
    /// 成功時は差し替え後の ClosetItem を返す (失敗時はトースト表示して nil)。
    func applyReplacement() async -> ClosetItem? {
        guard let selected, !isApplying,
              let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) else { return nil }
        isApplying = true
        defer { isApplying = false }

        // 原寸(高画質)を優先し、失敗したらサムネにフォールバック (検索追加と同じ)
        var downloaded = await Self.downloadImage(from: selected.originalURL)
        if downloaded == nil {
            downloaded = await Self.downloadImage(from: selected.thumbnailURL)
        }
        guard let image = downloaded else {
            ToastManager.shared.show("画像を取得できませんでした。別の画像をお試しください")
            return nil
        }

        let prepared = image.fixedOrientation().resizedToFit(longEdge: 1024)
        // クローゼットの他アイテムと見た目を揃える: 背景除去 → 正方形化 (失敗時も正方形化のみ行う)
        let working: UIImage
        if let cutout = try? await ItemNoiseRemover.removeBackgroundNoise(from: prepared),
           let squared = cutout.normalizedToContentSquare() {
            working = squared
        } else {
            working = prepared.normalizedToContentSquare() ?? prepared
        }
        guard let data = working.pngData() else {
            ToastManager.shared.show("差し替えに失敗しました")
            return nil
        }

        // 属性 (種類/カテゴリ/カラー) は元アイテムから引き継ぐ
        let metadata = BulkItemMetadata(
            index: 0,
            gender: UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue),
            main_category: nil,
            sub_category: nil,
            color: item.color,
            item_type: item.item_type,
            category: item.category,
            coordinate_id: nil
        )

        do {
            let result = try await registerClient.register(
                userId: uid,
                userToken: uid,  // user_token は user_id と同じ値を使用 (既存フローと同様)
                items: [(metadata: metadata, imageData: data)]
            )
            switch result {
            case .success(let response):
                guard response.success_count >= 1, let registered = response.items.first else {
                    ToastManager.shared.show("差し替えに失敗しました")
                    return nil
                }
                // 旧アイテムの削除はベストエフォート (失敗しても新画像は保存済み)
                var deletedOldItem = false
                if let deleteResult = try? await deleteClient.delete(uid: uid, itemId: item.id),
                   case .success(let deleteResponse) = deleteResult,
                   deleteResponse.success {
                    deletedOldItem = true
                }
                if !deletedOldItem {
                    ToastManager.shared.show("元の画像が残っています。不要な場合はクローゼットから削除してください", style: .normal)
                }
                return ClosetItem(
                    id: registered.id,
                    item_type: registered.item_type ?? item.item_type,
                    category: registered.category ?? item.category,
                    color: registered.color ?? item.color,
                    image_url: registered.storage_url,
                    date: item.date
                )
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "差し替えに失敗しました")
                return nil
            }
        } catch {
            ToastManager.shared.show("通信エラーが発生しました")
            return nil
        }
    }

    /// 画像を1件ダウンロードする (タイムアウト付き)。失敗時は nil。
    private static func downloadImage(from url: URL) async -> UIImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode < 400,
                  let image = UIImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }
}
