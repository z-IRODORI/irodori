//
//  RecommendCoordinateResponse.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/09/02.
//

import Foundation

struct RecommendCoordinateResponse: Codable {
    let coordinates: [RecommendCoordinate]
    let genres: [Genre]?
}

struct Genre: Codable {
    let genre: String
    let count: Int
}

struct AffiliateProduct: Codable, Hashable {
    let name: String
    let price: Int
    let url: String
    let image_url: String
    let store_name: String
}

extension RecommendCoordinateResponse {
    static func mock() -> RecommendCoordinateResponse {
        return RecommendCoordinateResponse(
            coordinates: [
                RecommendCoordinate(
                    id: 1, 
                    image_url: "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/12345",
                    coordinate_review: "全体的にシンプルで洗練されたコーディネートです。カジュアルながらも上品な印象を与える組み合わせで、様々なシーンで活用できそうなスタイルです。",
                    tops_categorize: "シャツ ストライプ ワイド ブラウン系",
                    bottoms_categorize: "パンツ 無地 ワイド ブラック",
                    affiliate_tops: [
                        AffiliateProduct(name: "ストライプシャツ", price: 2980, url: "https://example.com/1", image_url: "https://example.com/image1.jpg", store_name: "Fashion Store"),
                        AffiliateProduct(name: "ブラウンシャツ", price: 3200, url: "https://example.com/2", image_url: "https://example.com/image2.jpg", store_name: "Style Shop")
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(name: "ブラックパンツ", price: 4800, url: "https://example.com/3", image_url: "https://example.com/image3.jpg", store_name: "Pants Store"),
                        AffiliateProduct(name: "ワイドパンツ", price: 5200, url: "https://example.com/4", image_url: "https://example.com/image4.jpg", store_name: "Wide Shop")
                    ]
                ),
                RecommendCoordinate(
                    id: 2,
                    image_url: "https://i.pinimg.com/736x/82/77/a9/8277a98095eda2e3b1435905296dd056.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/67890",
                    coordinate_review: "落ち着いたカラーのチェックシャツとゆったりショートパンツのリラックス感あるカジュアルスタイル。休日のお出かけにぴったりです。",
                    tops_categorize: "シャツ チェック ワイド グレー系",
                    bottoms_categorize: "ショートパンツ 無地 ワイド チャコールグレー",
                    affiliate_tops: [
                        AffiliateProduct(name: "チェックシャツ", price: 3800, url: "https://example.com/5", image_url: "https://example.com/image5.jpg", store_name: "Check Store")
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(name: "グレーショーツ", price: 2800, url: "https://example.com/6", image_url: "https://example.com/image6.jpg", store_name: "Shorts Shop")
                    ]
                ),
                RecommendCoordinate(
                    id: 3,
                    image_url: "https://i.pinimg.com/736x/ef/5c/fa/ef5cfadb23b246687241c487a4e8c733.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/11111",
                    coordinate_review: "オーバーサイズのチェックシャツと黒のピンストライプワイドパンツでモード感とリラックス感を両立した大人カジュアル。",
                    tops_categorize: "シャツ チェック オーバーサイズ グレー",
                    bottoms_categorize: "パンツ ピンストライプ ワイド ブラック",
                    affiliate_tops: [],
                    affiliate_bottoms: []
                ),
                RecommendCoordinate(
                    id: 4,
                    image_url: "https://i.pinimg.com/736x/f1/4a/99/f14a99899c89588a6cac83481d4f6769.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/22222",
                    coordinate_review: nil,
                    tops_categorize: nil,
                    bottoms_categorize: nil,
                    affiliate_tops: [],
                    affiliate_bottoms: []
                ),
                RecommendCoordinate(
                    id: 5,
                    image_url: "https://i.pinimg.com/736x/3f/23/fa/3f23fa51d563253e78a5d31269d0d532.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/33333",
                    coordinate_review: "モノトーンでまとめたシンプルなスタイル。白シャツと黒パンツの定番コーディネートで、どんなシーンにも対応できます。",
                    tops_categorize: "シャツ 無地 レギュラー ホワイト",
                    bottoms_categorize: "パンツ 無地 スリム ブラック",
                    affiliate_tops: [
                        AffiliateProduct(name: "白シャツ", price: 2500, url: "https://example.com/7", image_url: "https://example.com/image7.jpg", store_name: "White Shop"),
                        AffiliateProduct(name: "ベーシックシャツ", price: 2800, url: "https://example.com/8", image_url: "https://example.com/image8.jpg", store_name: "Basic Store")
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(name: "スリムパンツ", price: 4200, url: "https://example.com/9", image_url: "https://example.com/image9.jpg", store_name: "Slim Store")
                    ]
                )
            ],
            genres: [
                Genre(genre: "casual", count: 3),
                Genre(genre: "korean", count: 2)
            ]
        )
    }
}
