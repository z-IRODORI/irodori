//
//  HomeResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/04.
//

import Foundation

struct HomeResponse: Codable {
    let answer: String
}

extension HomeResponse {
    static func mock() -> Self {
        .init(answer: "これはhogeですね")
    }
}
