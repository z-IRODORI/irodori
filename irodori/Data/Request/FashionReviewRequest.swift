//
//  FashionReviewRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import Foundation

struct FashionReviewRequest: Encodable {
    let user_id: String
    let user_token: String
    let file: Data   // 全身画像
}

extension FashionReviewRequest {
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["user_id"] = user_id
        parameters["user_token"] = user_token
        parameters["file"] = file
        return parameters
    }
}
