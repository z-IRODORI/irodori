//
//  WebItemImagesTests.swift
//  irodoriTests
//
//  「ネットで見つけた参考画像」(WebItemImagesRow) の検索ワード・クエリ導出の回帰テスト。
//  - ユーザーに見せる検索ワードは検出結果そのまま (例: "白 Tシャツ")
//  - 実際の検索クエリだけに「ユニクロ」を付ける (きれいな商品画像を優先ヒットさせるため)
//

import Foundation
import Testing
@testable import irodori

struct WebItemImagesTests {

    // MARK: - 検出結果 → 検索ワード (FashionReviewResponse.Item)

    private func makeItem(category: String?, color: String?, description: String?) -> FashionReviewResponse.Item {
        .init(
            id: "1",
            coordinate_id: "c1",
            item_type: "トップス",
            item_image_path: "",
            category: category,
            color: color,
            description: description
        )
    }

    // v2 の説明文は40字前後の文章で、検索クエリにすると画像がほぼヒットしないため「色 + カテゴリ」を優先する
    @Test("色とカテゴリがあれば説明文より優先する")
    func searchWordPrefersColorAndCategory() {
        let item = makeItem(category: "Tシャツ", color: "ホワイト", description: "白い無地のクルーネックTシャツ。程よい厚み")
        #expect(item.webImageSearchWord == "ホワイト Tシャツ")
    }

    @Test("色もカテゴリも無ければ説明文を検索ワードにする")
    func searchWordFallsBackToDescription() {
        let item = makeItem(category: nil, color: nil, description: "黒 レザー ライダースジャケット")
        #expect(item.webImageSearchWord == "黒 レザー ライダースジャケット")
    }

    @Test("説明文が無ければ「色 + カテゴリ」に落とす")
    func searchWordFallsBackToColorAndCategory() {
        let item = makeItem(category: "ジーンズ", color: "ブルー", description: nil)
        #expect(item.webImageSearchWord == "ブルー ジーンズ")

        // 空白だけの説明文も「無し」として扱う
        let spaces = makeItem(category: "ジーンズ", color: "ブルー", description: "   ")
        #expect(spaces.webImageSearchWord == "ブルー ジーンズ")
    }

    @Test("色もカテゴリも無ければ種類 (トップス等) に落とす")
    func searchWordFallsBackToItemType() {
        let item = makeItem(category: nil, color: " ", description: nil)
        #expect(item.webImageSearchWord == "トップス")
    }

    // MARK: - 検索クエリ (「ユニクロ」付与)

    @Test("検索クエリは「<検索ワード> ユニクロ」")
    func queryAppendsUniqlo() {
        #expect(WebItemImagesRowViewModel.searchQuery(for: "白 Tシャツ") == "白 Tシャツ ユニクロ")
    }

    @MainActor
    @Test("VM はユニクロ付きクエリ・10件指定で検索し、表示ワードは検出結果のまま")
    func viewModelSearchesWithUniqloQuery() async {
        let recorder = RecordingScraper()
        let vm = WebItemImagesRowViewModel(searchWord: "白 Tシャツ", scraper: recorder)
        await vm.loadIfNeeded()

        #expect(recorder.lastKeyword == "白 Tシャツ ユニクロ")
        #expect(recorder.lastLimit == 10)
        #expect(vm.searchWord == "白 Tシャツ")   // 表示用ワードにユニクロは付かない
        #expect(vm.results.count == 10)
        #expect(vm.errorMessage == nil)
    }
}

/// 呼び出しパラメータを記録するテスト用スクレイパー
private final class RecordingScraper: ImageSearchScraping {
    var lastKeyword: String?
    var lastLimit: Int?

    func search(keyword: String, gender: String?, limit: Int) async throws -> [SearchImageResult] {
        lastKeyword = keyword
        lastLimit = limit
        return (0..<limit).compactMap { index in
            guard let url = URL(string: "https://example.com/\(index).jpg") else { return nil }
            return SearchImageResult(thumbnailURL: url, originalURL: url)
        }
    }
}
