//
//  CoordinateRecommendRequest.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation

struct CoordinateRecommendRequest: Encodable {
    let gender: String
    let input_type: String
    let category: String
    let text: String
    let num_outfits: Int
    let num_candidates: Int
}
