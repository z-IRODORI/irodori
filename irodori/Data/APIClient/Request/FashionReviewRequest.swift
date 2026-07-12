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
    let file: Data   // 全身画像 (撮影画像)
    let tops_image: Data?   // MLモデルで検出したトップス画像
    let bottoms_image: Data?   // MLモデルで検出したボトムス画像
    let cutout_image: Data?   // iOSで人物切り取りした背景透過PNG (任意)
    let model: String? = "gemini-2.5-flash-lite"   // "gemini-2.5-flash" or "gemini-2.5-flash-lite" or "gemini-3-pro-preview"
}

extension FashionReviewRequest {
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["user_id"] = user_id
        parameters["user_token"] = user_token
        parameters["file"] = file
        if let tops_image = tops_image {
            parameters["tops_image"] = tops_image
        }
        if let bottoms_image = bottoms_image {
            parameters["bottoms_image"] = bottoms_image
        }
        if let cutout_image = cutout_image {
            parameters["cutout_image"] = cutout_image
        }
        parameters["model"] = model
        return parameters
    }
}
