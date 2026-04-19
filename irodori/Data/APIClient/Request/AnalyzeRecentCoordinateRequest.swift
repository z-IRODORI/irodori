//
//  AnalyzeRecentCoordinateRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/12.
//

import Foundation

struct AnalyzeRecentCoordinateRequest: Encodable {
    let uid: String
    let target_days: Int

    enum CodingKeys: String, CodingKey {
        case uid
        case target_days
    }
}
