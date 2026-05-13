//
//  DailyRecommendationResponse.swift
//  irodori
//
//  明日のコーデ推薦APIのレスポンス
//

import Foundation

struct DailyRecommendationItem: Decodable, Hashable, Identifiable {
    var id: String { pool_id }
    let pool_id: String
    let image_url: String
    let reason: String?
    let main_colors: [String]
    let items: [String: String?]
    let vibe: String
    let style: String          // backend: genre
    let cleanliness: Int
}

struct DailyRecommendationWeather: Decodable, Hashable {
    let min_temp: Int
    let max_temp: Int
    let condition: String
    let area_code: String
}

struct DailyRecommendationResponse: Decodable, Hashable {
    let target_date: String        // YYYY-MM-DD
    let weather: DailyRecommendationWeather
    let partner_comment: String?
    let recommendations: [DailyRecommendationItem]
    let mode: String               // "cached" | "fallback" | "refreshing"
}

struct WearMarkResponse: Decodable {
    let status: String
    let pool_id: String
    let worn_date: String
}

// MARK: - Mock

extension DailyRecommendationResponse {
    static func mock() -> Self {
        .init(
            target_date: "2026-05-14",
            weather: .init(min_temp: 16, max_temp: 23, condition: "晴れ時々曇り", area_code: "130000"),
            partner_comment: "明日は過ごしやすいから、ライトに春らしくいこう！",
            recommendations: (1...9).map { i in
                .init(
                    pool_id: "m_\(String(format: "%04d", i))",
                    image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg",
                    reason: "Sample reason \(i)",
                    main_colors: ["white", "navy"],
                    items: ["tops": "白Tシャツ", "bottoms": "ネイビーパンツ", "outer": nil, "accessory": nil],
                    vibe: "Sample vibe \(i)",
                    style: "casual",
                    cleanliness: (i % 5) + 1
                )
            },
            mode: "cached"
        )
    }
}
