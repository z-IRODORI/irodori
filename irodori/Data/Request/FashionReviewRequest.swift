//
//  FashionReviewRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import Foundation

// MARK: - Legacy FashionReviewRequest (for backward compatibility)
struct FashionReviewRequest: Encodable {
    var image: Data
    var user_token: String
    var outing_purpose_id: Int?   // TODO: BEに nil 以外も対応してもらう
    var query_width: Int = 500
    var query_height: Int = 500
}

// MARK: - API-Compatible FashionReviewRequest
struct APIFashionReviewRequest: Encodable {
    let user_id: String
    let user_token: String
    let days: Int
    let file: Data
    
    init(user_id: String, user_token: String, days: Int = 7, file: Data) {
        self.user_id = user_id
        self.user_token = user_token
        self.days = days
        self.file = file
    }
}

extension FashionReviewRequest {
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
