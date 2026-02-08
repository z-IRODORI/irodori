//
//  ChatResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/09.
//

import Foundation

struct ChatResponse: Codable {
    let answer: String
}

extension ChatResponse {
    static func mock() -> Self {
        .init(answer: "これはhogeですね")
    }
}
