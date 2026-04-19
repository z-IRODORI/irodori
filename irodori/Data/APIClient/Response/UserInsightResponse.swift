//
//  UserInsightResponse.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//

import Foundation

struct UserInsightResponse: Decodable, Hashable {
    let status: String
    let user_id: String
    let insight_id: String?
    let fashion_type: FashionTypeInfo?
    let animal_fortune: AnimalFortuneInfo?
    let insight: String
    let generated_at: String

    struct FashionTypeInfo: Decodable, Hashable {
        let type_code: String
        let type_name: String
        let description: String
        let core_stance: String
        let group: String
        let group_color: String
        let scores: Scores

        struct Scores: Decodable, Hashable {
            let trend_score: Double
            let self_score: Double
            let social_score: Double
            let function_score: Double
            let economy_score: Double
        }
    }

    struct AnimalFortuneInfo: Decodable, Hashable {
        let animal_number: Int
        let animal: String
        let animal_name: String
        let base_personality: String?
        let life_tendency: String?
        let female_feature: String?
        let male_feature: String?
        let love_tendency: String?
    }

    static func mock() -> UserInsightResponse {
        return UserInsightResponse(
            status: "success",
            user_id: "mock-user-123",
            insight_id: "mock-insight-id",
            fashion_type: FashionTypeInfo(
                type_code: "T-P-A-Q",
                type_name: "トレンド・エディター",
                description: "トレンドと自分らしさのバランスを重視するタイプ",
                core_stance: "トレンドを参考にしつつ、自分のスタイルを確立している",
                group: "TP",
                group_color: "#FF6B6B",
                scores: FashionTypeInfo.Scores(
                    trend_score: 4.0,
                    self_score: 4.0,
                    social_score: 3.0,
                    function_score: 2.0,
                    economy_score: 3.0
                )
            ),
            animal_fortune: AnimalFortuneInfo(
                animal_number: 3,
                animal: "tiger",
                animal_name: "虎",
                base_personality: "情熱的で行動力があり、自分の信念に従って生きるタイプ。",
                life_tendency: "目標に向かって邁進し、困難にも負けない強さを持つ。",
                female_feature: nil,
                male_feature: nil,
                love_tendency: nil
            ),
            insight: "直近のコーデを見ると、モノトーンを軸にした洗練されたスタイルが確立されていますね！ブラック×ホワイトの組み合わせが多く、シンプルながらも高級感のある着こなしが特徴的です。",
            generated_at: "2024-03-12T10:30:45.123456"
        )
    }
}
