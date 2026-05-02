//
//  ChatWithHistoryRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import Foundation

struct ChatWithHistoryRequest: Encodable {
    let user_id: String
    let question: String
    let gender: Gender
    let image_base64: String?
    let model: String? = nil

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(question, forKey: .question)
        try container.encode(gender.apiValue, forKey: .gender)
        try container.encodeIfPresent(image_base64, forKey: .image_base64)
        try container.encodeIfPresent(model, forKey: .model)
    }

    enum CodingKeys: String, CodingKey {
        case user_id, question, gender, image_base64, model
    }
}
