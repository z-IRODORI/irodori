//
//  FashionReviewResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import Foundation

struct FashionReviewResponse: Decodable, Hashable {
    var current_coordinate: CurrentCoordinate
    var recent_coordinates: [RecentCoordinate]
    var items: [Item]
    var ai_catchphrase: String
    var ai_review_comment: String
    var tags: [String]?
    var item_types: [String]?

    struct CurrentCoordinate: Decodable, Hashable {
        var id: String
        var date: String
        var coodinate_image_path: String
    }

    struct Item: Decodable, Hashable {
        var id: String
        var coordinate_id: String
        var item_type: String
        var item_image_path: String
        var category: String?       // 例: "Tシャツ", "ジーンズ"
        var color: String?          // 例: "ホワイト", "ブラック"
        var description: String?    // 例: "黒 レザー ライダースジャケット"
    }
}

// MARK: - Mock

extension FashionReviewResponse {
    static func mock() -> Self {
        .init(
            current_coordinate: .init(
                id: "1",
                date: "2025/01/01",
                coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/yMN071qf/1752555537_1000.jpg"
            ),
            recent_coordinates: [
                .init(id: "1", date: "2025/01/01", image_url: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
                .init(id: "2", date: "2025/01/02", image_url: "https://images.wear2.jp/coordinate/bBildLXx/GSrtWHRb/1751733151_1000.jpg"),
                .init(id: "3", date: "2025/01/03", image_url: "https://images.wear2.jp/coordinate/bBildLXx/NUZmuZyQ/1751726257_1000.jpg"),
                .init(id: "4", date: "2025/01/04", image_url: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
                .init(id: "5", date: "2025/01/05", image_url: "https://images.wear2.jp/coordinate/bBildLXx/augDFt7T/1751359316_1000.jpg"),
            ],
            items: [
                .init(
                    id: "1",
                    coordinate_id: "1",
                    item_type: "トップス",
                    item_image_path: "https://c.imgz.jp/860/92598860/92598860b_b_81_500.jpg",
                    category: "Tシャツ",
                    color: "ホワイト",
                    description: "ホワイト コットン Tシャツ"
                ),
                .init(
                    id: "2",
                    coordinate_id: "1",
                    item_type: "ボトムス",
                    item_image_path: "https://c.imgz.jp/394/92427394/92427394b_b_66_500.jpg",
                    category: "ジーンズ",
                    color: "ブルー",
                    description: "ブルー デニム ジーンズ"
                ),
                .init(
                    id: "3",
                    coordinate_id: "1",
                    item_type: "シューズ",
                    item_image_path: "",
                    category: "スニーカー",
                    color: "ブラック",
                    description: "ブラック キャンバス スニーカー"
                ),
            ],
            ai_catchphrase: "明るさ全開の朝ドラ女優",
            ai_review_comment: """
              控えめで自己主張が苦手。
              
              **他者からの見られ方**
              周囲には知的でセンスの良い印象を与え、同年代からは親しみやすくも頼れる存在として見られます。目上の人からは誠実かつ控えめ
              な印象を持たれ、目下からは信頼される優しい先輩像として慕われるでしょう。
              
              **改善点, 伸ばせば良いポイント**
              黒パンツと靴の落ち着いたトーンが全体を引き締めていますが、バッグの素材感や色味に少し遊びを加えるとより個性が際立ちます。
              アクセサリーでさりげない光沢や色を取り入れるのも効果的です。
              """,
            tags: ["レザージャケットコーデ", "ブラックコーデ", "大人カジュアル", "赤バッグを差す勇気", "クールな眼差しの正体",
                   "静と動を纏う人", "金曜日の夜に出かけたい"],
            item_types: ["トップス", "ボトムス", "シューズ"]
        )
    }
}
