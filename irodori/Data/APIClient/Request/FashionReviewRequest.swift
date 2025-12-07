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
    let model: String? = "gemini-3-pro-preview"   // "gemini-2.5-flash" or "gemini-2.5-flash-lite" or "gemini-3-pro-preview"
}

extension FashionReviewRequest {
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["user_id"] = user_id
        parameters["user_token"] = user_token
        parameters["file"] = file
        parameters["model"] = model
        return parameters
    }
}
