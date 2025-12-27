//
//  HomeResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct HomeResponse: Decodable, Hashable {
    var recent_coordinates: [RecentCoordinate]
    var coordinate_analyze: String
    var tags: [String]?
}

// MARK: - Mock

extension HomeResponse {
    static func mock() -> Self {
        .init(
            recent_coordinates: [],
//            recent_coordinates: [
//                .init(id: "1", date: "2025/01/01", coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
//                .init(id: "2", date: "2025/01/02", coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/GSrtWHRb/1751733151_1000.jpg"),
//                .init(id: "3", date: "2025/01/03", coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/NUZmuZyQ/1751726257_1000.jpg"),
//                .init(id: "4", date: "2025/01/04", coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
//                .init(id: "5", date: "2025/01/05", coodinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/augDFt7T/1751359316_1000.jpg"),
//            ],
            coordinate_analyze: "",
//            coordinate_analyze: "コーデ分析の主要な傾向は二つです。\nまず、**オールブラック／ダークトーン**の着こなしでは、レザーとニットなどの**異素材の質感**を重ねることで、単調さを避け、知的な深みと洗練されたムードを追求しています。小物使いでメリハリを出す点も特徴的です。\n\nもう一つは、**リラックススタイルからの脱却**です。",
//            coordinate_analyze: "コーデ分析の主要な傾向は二つです。\nまず、**オールブラック／ダークトーン**の着こなしでは、レザーとニットなどの**異素材の質感**を重ねることで、単調さを避け、知的な深みと洗練されたムードを追求しています。小物使いでメリハリを出す点も特徴的です。\n\nもう一つは、**リラックススタイルからの脱却**です。オーバーサイズによる「だらしなさ」や「部屋着感」が指摘され、大人カジュアルへの改善が焦点です。具体的には、トップスをコンパクトに、パンツをテーパードシルエットにするなど、**シルエットのメリハリ**を明確にすることで、重心を上げ、**清潔感と抜け感**を出す工夫が強く推奨されています。\n\n全体として、単なる流行よりも**清潔感、メリハリ、個性**を両立させた「大人の余裕ある着こなし」が重視されています。",
            tags: nil//["レザージャケットコーデ", "ブラックコーデ", "大人カジュアル", "赤バッグを差す勇気", "クールな眼差しの正体", "静と動を纏う人", "金曜日の夜に出かけたい"]
        )
    }
}
