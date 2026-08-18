//
//  ItemCoordinatesResponse.swift
//  irodori
//

import Foundation

/// GET /api/item/{item_id}/coordinates のレスポンス。
/// アイテム詳細 + そのアイテム (同カテゴリ×同カラー) を使ったコーデ一覧。
struct ItemCoordinatesResponse: Decodable, Hashable {
    var item_id: String
    var item_type: String?
    var category: String?      // アイテム名 (Tシャツ 等)
    var color: String?
    var description: String?   // 特徴 (生地感・サイズ感)
    var image_url: String?
    var coordinates: [CoordinateSummary]

    struct CoordinateSummary: Decodable, Hashable, Identifiable {
        var coordinate_id: String
        var date: String
        var coordinate_image_path: String
        var cutout_image_path: String?
        var display_type: String?
        var ai_catchphrase: String

        var id: String { coordinate_id }

        /// 一覧に出す画像URL (display_type に応じて撮影/切り取りを選択)
        var displayImageURL: String {
            CoordinateImageResolver.url(
                captured: coordinate_image_path,
                cutout: cutout_image_path,
                displayType: display_type
            ) ?? coordinate_image_path
        }
    }
}

// MARK: - Mock

extension ItemCoordinatesResponse {
    static func mock() -> Self {
        .init(
            item_id: "item-1",
            item_type: "アウター",
            category: "チェスターコート",
            color: "ベージュ",
            description: "上質なウール調の生地感で、膝上丈のすっきりとしたシルエット。",
            image_url: "https://c.imgz.jp/860/92598860/92598860b_b_81_500.jpg",
            coordinates: [
                .init(coordinate_id: "1", date: "2026/08/10",
                      coordinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/yMN071qf/1752555537_1000.jpg",
                      cutout_image_path: nil, display_type: "captured",
                      ai_catchphrase: "都会的な大人の休日スタイル"),
                .init(coordinate_id: "2", date: "2026/08/03",
                      coordinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg",
                      cutout_image_path: nil, display_type: "captured",
                      ai_catchphrase: "きれいめカジュアルの好例"),
            ]
        )
    }
}
