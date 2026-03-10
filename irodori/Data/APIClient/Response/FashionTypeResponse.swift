//
//  FashionTypeResponse.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import Foundation

struct FashionTypeResponse: Decodable, Hashable {
    let diagnosis_id: String
    let type_code: String
    let type_name: String
    let trend_score: Double
    let self_score: Double
    let social_score: Double
    let function_score: Double
    let economy_score: Double
    let created_at: String

    static func mock() -> FashionTypeResponse {
        return FashionTypeResponse(
            diagnosis_id: "mock-diagnosis-id",
            type_code: "T-P-A-Q",
            type_name: "アヴァンギャルド・スター",
            trend_score: 4.5,
            self_score: 4.0,
            social_score: 3.0,
            function_score: 2.5,
            economy_score: 2.0,
            created_at: "2026-03-09T12:00:00Z"
        )
    }
}
