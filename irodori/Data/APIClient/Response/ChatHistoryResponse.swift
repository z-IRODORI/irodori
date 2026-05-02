//
//  ChatHistoryResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/05/01.
//

import Foundation

struct ConversationResponse: Codable, Identifiable {
    let conversation_id: String
    let type: String
    let coordinate_id: String?
    let created_at: String
    let last_updated: String
    let message_count: Int
    let last_message_preview: String?

    var id: String { conversation_id }
}

struct ChatMessageRecord: Codable, Identifiable {
    let id: String
    let text: String
    let is_user: Bool
    let created_at: String

    var asChatMessage: ChatMessage {
        let date = ISO8601DateFormatter().date(from: created_at) ?? Date()
        return ChatMessage(id: id, text: text, isUser: is_user, timestamp: date)
    }
}

struct ChatHistoryResponse: Codable {
    let conversation_id: String
    let messages: [ChatMessageRecord]
}

struct ChatWithHistoryResponse: Codable {
    let user_message: ChatMessageRecord
    let ai_message: ChatMessageRecord
}
