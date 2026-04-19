//
//  HomeResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct HomeResponse: Decodable, Hashable {
    var recent_coordinates: [RecentCoordinate]
    var analysis_summary: String
    var tags: [String]?

    // 後方互換性のため、古いフィールド名もサポート
    enum CodingKeys: String, CodingKey {
        case recent_coordinates
        case analysis_summary
        case coordinate_analyze
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recent_coordinates = try container.decode([RecentCoordinate].self, forKey: .recent_coordinates)
        tags = try? container.decode([String].self, forKey: .tags)

        // analysis_summaryを優先的に読み取り、なければcoordinate_analyzeを使用
        if let analysisSummary = try? container.decode(String.self, forKey: .analysis_summary) {
            analysis_summary = analysisSummary
        } else if let coordinateAnalyze = try? container.decode(String.self, forKey: .coordinate_analyze) {
            analysis_summary = coordinateAnalyze
        } else {
            analysis_summary = ""
        }
    }

    init(recent_coordinates: [RecentCoordinate], analysis_summary: String, tags: [String]?) {
        self.recent_coordinates = recent_coordinates
        self.analysis_summary = analysis_summary
        self.tags = tags
    }
}

// MARK: - Mock

extension HomeResponse {
    static func mock() -> Self {
        .init(
            recent_coordinates: [
                .init(id: "1", date: "2025/01/01", image_url: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
                .init(id: "2", date: "2025/01/02", image_url: "https://images.wear2.jp/coordinate/bBildLXx/GSrtWHRb/1751733151_1000.jpg"),
                .init(id: "3", date: "2025/01/03", image_url: "https://images.wear2.jp/coordinate/bBildLXx/NUZmuZyQ/1751726257_1000.jpg"),
                .init(id: "4", date: "2025/01/04", image_url: "https://images.wear2.jp/coordinate/bBildLXx/iO87m45l/1751811504_1000.jpg"),
                .init(id: "5", date: "2025/01/05", image_url: "https://images.wear2.jp/coordinate/bBildLXx/augDFt7T/1751359316_1000.jpg"),
            ],
            analysis_summary: "コーデ分析の主要な傾向は二つです。\nまず、**オールブラック／ダークトーン**の着こなしでは、レザーとニットなどの**異素材の質感**を重ねることで、単調さを避け、知的な深みと洗練されたムードを追求しています。小物使いでメリハリを出す点も特徴的です。\n\nもう一つは、**リラックススタイルからの脱却**です。",
            tags: ["レザージャケットコーデ", "ブラックコーデ", "大人カジュアル", "赤バッグを差す勇気", "クールな眼差しの正体", "静と動を纏う人", "金曜日の夜に出かけたい"]
        )
    }
}
