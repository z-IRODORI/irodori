//
//  RecommendCoordinateResponse.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/09/02.
//

import Foundation

struct RecommendCoordinateResponse: Codable {
    let coordinates: [RecommendCoordinate]
    let recommend_reasons: String?
    let genres: [Genre]?
}

struct RecommendCoordinate: Codable, Hashable {
    let id: Int
    let image_url: String
    let pin_url_guess: String
    let coordinate_review: String?
    let tops_categorize: String?
    let bottoms_categorize: String?
    let affiliate_tops: [AffiliateProduct]
    let affiliate_bottoms: [AffiliateProduct]
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
                        AffiliateProduct(
                            name: "tシャツ 「別注」 「Hanes」 ビーフィー Tシャツ メンズ",
                            price: 3630,
                            url: "https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=3753143&pid=892044669&vc_url=https%3A%2F%2Fstore.shopping.yahoo.co.jp%2Fzozo%2F91840174.html",
                            image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174",
                            store_name: "ZOZOTOWN Yahoo!店"
                        ),
                        AffiliateProduct(
                            name: "tシャツ HYSTERIC RABBIT Tシャツ メンズ",
                            price: 14300,
                            url: "https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=3753143&pid=892044669&vc_url=https%3A%2F%2Fstore.shopping.yahoo.co.jp%2Fzozo%2F96062258.html",
                            image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_96062258",
                            store_name: "ZOZOTOWN Yahoo!店"
                        )
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(
                            name: "水着 「NIKE」ナイキ/メンズ水着/水陸両用/ユーティリティー ヒーロースタイル9ボレーショーツ ショーツ NESSF558 メンズ レディース",
                            price: 4312,
                            url: "https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=3753143&pid=892044669&vc_url=https%3A%2F%2Fstore.shopping.yahoo.co.jp%2Fzozo%2F92760902.html",
                            image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_92760902",
                            store_name: "ZOZOTOWN Yahoo!店"
                        ),
                        AffiliateProduct(
                            name: "パンツ BEAMS / ベーシック チノショーツ メンズ",
                            price: 4851,
                            url: "https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=3753143&pid=892044669&vc_url=https%3A%2F%2Fstore.shopping.yahoo.co.jp%2Fzozo%2F91595580.html",
                            image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91595580",
                            store_name: "ZOZOTOWN Yahoo!店"
                        )
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
                        AffiliateProduct(name: "チェックシャツ", price: 3800, url: "https://zozo.jp/shop/example/goods/91840178/", image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174", store_name: "Check Store")
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(name: "グレーショーツ", price: 2800, url: "https://zozo.jp/shop/example/goods/91840179/", image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174", store_name: "Shorts Shop")
                    ]
                ),
                RecommendCoordinate(
                    id: 3,
                    image_url: "https://i.pinimg.com/736x/3f/23/fa/3f23fa51d563253e78a5d31269d0d532.jpg", 
                    pin_url_guess: "https://pinterest.com/pin/33333",
                    coordinate_review: "モノトーンでまとめたシンプルなスタイル。白シャツと黒パンツの定番コーディネートで、どんなシーンにも対応できます。",
                    tops_categorize: "シャツ 無地 レギュラー ホワイト",
                    bottoms_categorize: "パンツ 無地 スリム ブラック",
                    affiliate_tops: [
                        AffiliateProduct(name: "白シャツ", price: 2500, url: "https://zozo.jp/shop/example/goods/91840180/", image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174", store_name: "White Shop"),
                        AffiliateProduct(name: "ベーシックシャツ", price: 2800, url: "https://zozo.jp/shop/example/goods/91840181/", image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174", store_name: "Basic Store")
                    ],
                    affiliate_bottoms: [
                        AffiliateProduct(name: "スリムパンツ", price: 4200, url: "https://zozo.jp/shop/example/goods/91840182/", image_url: "https://item-shopping.c.yimg.jp/i/g/zozo_91840174", store_name: "Slim Store")
                    ]
                )
            ],
            recommend_reasons: "ブラックを基調としたミニマルなスタイルに、チェック柄のシャツを重ね着し、カジュアルさとアクセントを加えることで、単調になりがちなモノトーンコーデに深みと個性をプラスできます。また、ダメージジーンズを取り入れれば、リラックスした雰囲気を演出しつつ、都会的なブラックコーデのカジュアルダウンとしても活躍します。柄や素材感で遊ぶことで、シックな中にも抜け感と遊び心が生まれます。",
            genres: [
                Genre(genre: "casual", count: 3),
                Genre(genre: "korean", count: 2)
            ]
        )
    }
}
