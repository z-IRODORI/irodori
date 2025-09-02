//
//  RecommendCoordinateRequest.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/09/02.
//

import Foundation

struct RecommendCoordinateRequest: Codable {
    let gender: String
    
    func createParameters() -> [String: Any] {
        return [
            "gender": gender
        ]
    }
}