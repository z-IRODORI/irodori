//
//  FashionReviewMockData.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - APIFashionReviewResponse Mock Data

extension APIFashionReviewResponse {
    static func mockData() -> APIFashionReviewResponse {
        return APIFashionReviewResponse(
            current_coordinate: APICoordinateResponseDetail.mockData(),
            recent_coordinates: APICoordinateResponseDetail.mockDataList(),
            items: APICoordinateItem.mockDataList(),
            ai_comment: mockAIComment()
        )
    }
    
    private static func mockAIComment() -> String {
        return "素敵なコーディネートですね！全体的にバランスが取れていて、色の組み合わせも素晴らしいです。"
    }
}