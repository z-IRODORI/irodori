import Foundation

struct AnalysisCoordinateResponse: Decodable {
    let id: Int
    let coordinate_review: String?
    let tops_categorize: String?
    let bottoms_categorize: String?
    let affiliate_tops: [AffiliateProduct]
    let affiliate_bottoms: [AffiliateProduct]
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

extension AnalysisCoordinateResponse {
    static let mock = AnalysisCoordinateResponse(
        id: 1234567890,
        coordinate_review: "全体的にシンプルで洗練されたコーディネートです。カジュアルながらも上品な印象を与える組み合わせで、様々なシーンで活用できそうなスタイルです。色のバランスも良く、統一感のある仕上がりになっています。",
        tops_categorize: "シャツ ストライプ ワイド ホワイト系",
        bottoms_categorize: "パンツ 無地 ワイド グレー",
        affiliate_tops: [
            AffiliateProduct(name: "ストライプシャツ", price: 2980, url: "https://example.com/1", image_url: "https://example.com/image1.jpg", store_name: "Fashion Store"),
            AffiliateProduct(name: "ホワイトシャツ", price: 3500, url: "https://example.com/2", image_url: "https://example.com/image2.jpg", store_name: "Style Shop")
        ],
        affiliate_bottoms: [
            AffiliateProduct(name: "グレーパンツ", price: 4800, url: "https://example.com/3", image_url: "https://example.com/image3.jpg", store_name: "Pants Store"),
            AffiliateProduct(name: "ワイドパンツ", price: 5200, url: "https://example.com/4", image_url: "https://example.com/image4.jpg", store_name: "Wide Shop")
        ]
    )

    static let mockEmpty = AnalysisCoordinateResponse(
        id: 9876543210,
        coordinate_review: nil,
        tops_categorize: nil,
        bottoms_categorize: nil,
        affiliate_tops: [],
        affiliate_bottoms: []
    )
}
