//
//  PredictResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/03.
//

import Foundation

struct PredictResponse: Decodable {
    let graph_image: String
    let similar_wear: [SimilarWearItem]
}

struct SimilarWearItem: Decodable {
    let username: String
    let image_base64: String
}
