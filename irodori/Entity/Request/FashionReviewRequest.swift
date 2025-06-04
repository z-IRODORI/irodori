//
//  FashionReviewRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import Foundation

struct FashionReviewRequest: Encodable {
    var image: Data
    var user_token: String
    var outing_purpose_id: Int?   // TODO: BEに nil 以外も対応してもらう
    var query_width: Int = 500
    var query_height: Int = 500
}

extension FashionReviewRequest {
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["image"] = image
        parameters["user_token"] = user_token
        parameters["outing_purpose_id"] = outing_purpose_id ?? ""
        parameters["query_width"] = query_width
        parameters["query_height"] = query_height
        print(parameters)
        return parameters
    }
}
