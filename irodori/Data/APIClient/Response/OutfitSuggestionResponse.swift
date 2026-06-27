//
//  OutfitSuggestionResponse.swift
//  irodori
//
//  「相棒が予定に合わせて次に着るコーデを提案」APIのレスポンス。
//  相棒コメント + スナップからおすすめ(明日のコーデと同形式) + クローゼットからコーデ をまとめて返す。
//

import Foundation

struct OutfitSuggestionResponse: Decodable, Hashable {
    let status: String
    let target_date: String
    let weather: DailyRecommendationWeather
    let partner_comment: String
    let snap: DailyRecommendationResponse      // スナップからおすすめ(9件)
    let closet: OutfitCollageResponse          // クローゼットからコーデ
}

// MARK: - Mock

extension OutfitSuggestionResponse {
    static func mock() -> Self {
        .init(
            status: "success",
            target_date: "2026-06-28",
            weather: .init(min_temp: 20, max_temp: 28, condition: "晴れ", area_code: "130000"),
            partner_comment: "これまではカジュアル多めだったよね！今日はデートで上品に見せたいなら、白シャツ×ネイビーのきれいめが好相性。あなたの清潔感がぐっと引き立つよ✨",
            snap: .mock(),
            closet: .mock()
        )
    }
}
