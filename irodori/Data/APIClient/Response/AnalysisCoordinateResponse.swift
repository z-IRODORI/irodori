import Foundation

struct AnalysisCoordinateResponse: Decodable {
    let id: Int
    let coordinate_review: String?
    let tops_categorize: String?
    let bottoms_categorize: String?
}

extension AnalysisCoordinateResponse {
    static let mock = AnalysisCoordinateResponse(
        id: 1234567890,
        coordinate_review: "全体的にシンプルで洗練されたコーディネートです。カジュアルながらも上品な印象を与える組み合わせで、様々なシーンで活用できそうなスタイルです。色のバランスも良く、統一感のある仕上がりになっています。",
        tops_categorize: "シャツ ストライプ ワイド ホワイト系",
        bottoms_categorize: "パンツ 無地 ワイド グレー"
    )

    static let mockEmpty = AnalysisCoordinateResponse(
        id: 9876543210,
        coordinate_review: nil,
        tops_categorize: nil,
        bottoms_categorize: nil
    )
}
