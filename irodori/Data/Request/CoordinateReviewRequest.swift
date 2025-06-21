//
//  CoordinateReviewRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/11.
//

import Foundation

struct CoordinateReviewRequest: Encodable {
    let image_base64: String
    let outing_purpose_id: Int
}
