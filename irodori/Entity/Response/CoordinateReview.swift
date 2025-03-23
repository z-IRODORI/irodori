//
//  CoordinateReview.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/24.
//

import Foundation

// APIを作った場合使う
struct CoordinateReview {
    let id: Int
    let coordinateReview: String
    let recommend: [RecommendItems]
}

struct RecommendItems {
    let id: Int
    let title: String    // 黒のワイドパンツ に似合う レザージャケット
    let recommendItems: [RecommendItem]
}

struct RecommendItem {
    let id: Int
    let name: String
    let company: String
    let price: Int
    let imageURL: String
    let itemURL: String
}

// MARK: - Mock

extension CoordinateReview {
    static func mock() -> Self {
        let id: Int = 1
        let coordinateReview: String = """
        黒のショルダーバッグがシンプルでコーデの引き締め役になっていて素敵ですね。
        トップスを軽くインしているので、ラフすぎず清潔感があります。\n程よくワイドなパンツを履いているので、リラックス感のある大人な印象を受けます。
        あなたのシルエットは「I」です。Iが似合うのは、縦長でスタイリッシュな印象を好む方や、シンプルで洗練された雰囲気を持った方です。
        また、あなたのコーデはカジュアルです。
        カジュアルが似合う方におすすめのコーデタイプは、シンプルで洗練された印象が特徴のノームコアです。
        画像の黒パンツに合うのは、白や淡いブルーのシャツです。理由としては、黒のパンツと明るい色味のシャツは相性がよく、シンプルながら爽やかで大人っぽい印象になるからです。
        """
        let recommend: [RecommendItems] = [
            .init(id: 1, title: "あなたのワイドパンツに合う レザージャケット",
                  recommendItems: [
                    .init(id: 1, name: "ブルゾン", company: "Java", price: 4998, imageURL: "https://c.imgz.jp/401/75323401/75323401b_8_d_215.jpg", itemURL: "https://zozo.jp/shop/classicalelf/goods-sale/74323401/?did=121927532"),
                    .init(id: 2, name: "ブルゾン", company: "DISCOAT", price: 13200, imageURL: "https://c.imgz.jp/812/77116812/77116812b_8_d_215.jpg", itemURL: "https://zozo.jp/shop/discoat/goods/76116812/?did=124587584"),
                    .init(id: 3, name: "ブルゾン", company: "Starting Over", price: 6930, imageURL: "https://c.imgz.jp/563/88838563/88838563b_152_d_215.jpg", itemURL: "https://zozo.jp/shop/startingover/goods-sale/87838563/?did=142444018"),
                    .init(id: 4, name: "ブルゾン", company: "Starting Over", price: 7920, imageURL: "https://c.imgz.jp/735/88461735/88461735b_8_d_215.jpg", itemURL: "https://zozo.jp/shop/startingover/goods-sale/87461735/?did=141864675"),
                    .init(id: 5, name: "ブルゾン", company: "BEAMS", price: 50600, imageURL: "https://c.imgz.jp/554/79150554/79150554b_8_d_215.jpg", itemURL: "https://zozo.jp/shop/beams/goods/78150554/?did=127820453"),
                ]),
            .init(id: 1, title: "あなたのグレーのニットに合う デニムパンツ",
                  recommendItems: [
                    .init(id: 1, name: "", company: "Levi's", price: 9350, imageURL: "https://c.imgz.jp/052/38900052/38900052b_8_d_215.jpg", itemURL: "https://zozo.jp/shop/levisstore/goods/37900052/?did=111454083"),
                    .init(id: 2, name: "", company: "Levi's", price: 9350, imageURL: "https://c.imgz.jp/052/38900052/38900052b_5_d_215.jpg", itemURL: "https://zozo.jp/shop/levisstore/goods/37900052/?did=114636341"),
                    .init(id: 3, name: "", company: "Levi's", price: 9350, imageURL: "https://c.imgz.jp/052/38900052/38900052b_33_d_215.jpg", itemURL: "https://zozo.jp/shop/levisstore/goods/37900052/?did=111454114"),
                    .init(id: 4, name: "", company: "Levi's", price: 9350, imageURL: "https://c.imgz.jp/052/38900052/38900052b_165_d_215.jpg", itemURL: "https://zozo.jp/shop/levisstore/goods/37900052/?did=65020623"),
                    .init(id: 5, name: "", company: "Levi's", price: 9350, imageURL: "https://c.imgz.jp/052/38900052/38900052b_64_d_215.jpg", itemURL: "https://zozo.jp/shop/levisstore/goods/37900052/?did=131315989"),
                ]),
        ]

        return .init(id: id, coordinateReview: coordinateReview, recommend: recommend)
    }
}
