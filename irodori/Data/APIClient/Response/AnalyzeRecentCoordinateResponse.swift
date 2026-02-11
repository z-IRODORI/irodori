//
//  AnalyzeRecentCoordinateResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/12.
//

import Foundation

struct AnalyzeRecentCoordinateResponse: Decodable {
    let analyze_recent_coordinate: String

    enum CodingKeys: String, CodingKey {
        case analyze_recent_coordinate
    }
}
