//
//  LegacyFashionReviewRequest.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - Legacy FashionReviewRequest (for FashionReviewClient)

struct FashionReviewRequest: Encodable {
    var image: Data
    var user_token: String
    var outing_purpose_id: Int?
    var query_width: Int = 500
    var query_height: Int = 500
    
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["image"] = image
        parameters["user_token"] = user_token
        parameters["outing_purpose_id"] = outing_purpose_id ?? ""
        parameters["query_width"] = query_width
        parameters["query_height"] = query_height
        return parameters
    }
}

// MARK: - Legacy CoordinateReviewRequest (for GPTClient)

struct CoordinateReviewRequest: Encodable {
    let image_base64: String
    let outing_purpose_id: Int
}