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
    
    static func mockDataWithCustomComment(_ comment: String) -> APIFashionReviewResponse {
        return APIFashionReviewResponse(
            current_coordinate: APICoordinateResponseDetail.mockData(),
            recent_coordinates: APICoordinateResponseDetail.mockDataList(),
            items: APICoordinateItem.mockDataList(),
            ai_comment: comment
        )
    }
    
    private static func mockAIComment() -> String {
        return """
        素敵なコーディネートですね！全体的にバランスが取れていて、色の組み合わせも素晴らしいです。
        
        特に上半身のアイテムが印象的で、季節感も考慮されたスタイリングになっています。
        
        今回のコーディネートは、カジュアルながらも上品さを兼ね備えており、様々なシーンで活用できそうです。
        """
    }
    
    static func mockPositiveReview() -> APIFashionReviewResponse {
        return mockDataWithCustomComment("""
        とても素敵なコーディネートです！色合いが美しく調和しており、全体のバランスも完璧です。
        このスタイリングは上品で洗練された印象を与えます。
        """)
    }
    
    static func mockConstructiveReview() -> APIFashionReviewResponse {
        return mockDataWithCustomComment("""
        良いコーディネートのベースができています。さらに魅力的にするために、アクセサリーを加えることをおすすめします。
        また、異なる色味のシューズを試すことで、より個性的なスタイルになるでしょう。
        """)
    }
}