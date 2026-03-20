//
//  ChatRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/09.
//

import Foundation

struct ChatRequest: Encodable {
    let question: String
    let gender: Gender
    let model: String? = "gemini-3.1-flash-lite-preview"   // "gemini-2.5-flash" or "gemini-2.5-flash-lite" or "gemini-3-pro-preview"
    let image_base64: String

    enum CodingKeys: String, CodingKey {
        case question
        case gender
        case model
        case image_base64
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(question, forKey: .question)
        try container.encode(gender.apiValue, forKey: .gender)  // API値をエンコード
        try container.encode(model, forKey: .model)
        try container.encode(image_base64, forKey: .image_base64)
    }
}
