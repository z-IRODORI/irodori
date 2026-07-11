//
//  KeywordItemSearchViewModel.swift
//  irodori
//
//  キーワードで画像を検索し、候補URLをグリッド表示するための状態を管理する。
//  検索は ImageSearchScraper (隠しWebView) 経由で、バックエンドは使わない。
//

import Foundation
import Observation

@MainActor
@Observable
final class KeywordItemSearchViewModel {
    var keyword: String = ""
    var isSearching = false
    var results: [SearchImageResult] = []
    var errorMessage: String?
    /// 一度でも検索を実行したか (初期の空状態と「0件」を区別する)
    var hasSearched = false

    private let scraper: ImageSearchScraping

    // ImageSearchScraper は @MainActor のため、デフォルト引数(非分離で評価)では
    // 生成できない。nil を既定にし、@MainActor な init 本体で生成する。
    init(scraper: ImageSearchScraping? = nil) {
        self.scraper = scraper ?? ImageSearchScraper()
    }

    func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        results = []
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
}
