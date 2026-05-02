//
//  ChatClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/09.
//

import Foundation

protocol ChatClientProtocol {
    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError>
    func createConversation(userId: String, type: String, coordinateId: String?, forceNew: Bool) async throws -> Result<ConversationResponse, HTTPError>
    func fetchMessages(conversationId: String, userId: String, limit: Int) async throws -> Result<ChatHistoryResponse, HTTPError>
    func postWithHistory(conversationId: String, request: ChatWithHistoryRequest) async throws -> Result<ChatWithHistoryResponse, HTTPError>
    func fetchConversations(userId: String, limit: Int) async throws -> Result<[ConversationResponse], HTTPError>
}

final class ChatClient: ChatClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError> {
        let url = URL(string: "\(baseURL)/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONEncoder().encode(chatRequest)
        return await perform(request: request, decoding: ChatResponse.self)
    }

    func createConversation(userId: String, type: String, coordinateId: String?, forceNew: Bool = false) async throws -> Result<ConversationResponse, HTTPError> {
        let url = URL(string: "\(baseURL)/api/chat/conversations")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        struct Body: Encodable { let user_id: String; let type: String; let coordinate_id: String?; let force_new: Bool }
        urlRequest.httpBody = try JSONEncoder().encode(Body(user_id: userId, type: type, coordinate_id: coordinateId, force_new: forceNew))
        return await perform(request: urlRequest, decoding: ConversationResponse.self)
    }

    func fetchMessages(conversationId: String, userId: String, limit: Int = 20) async throws -> Result<ChatHistoryResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/chat/conversations/\(conversationId)/messages")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30
        return await perform(request: urlRequest, decoding: ChatHistoryResponse.self)
    }

    func postWithHistory(conversationId: String, request: ChatWithHistoryRequest) async throws -> Result<ChatWithHistoryResponse, HTTPError> {
        let url = URL(string: "\(baseURL)/api/chat/conversations/\(conversationId)/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120
        urlRequest.httpBody = try JSONEncoder().encode(request)
        return await perform(request: urlRequest, decoding: ChatWithHistoryResponse.self)
    }

    func fetchConversations(userId: String, limit: Int = 20) async throws -> Result<[ConversationResponse], HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/chat/conversations")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 30
        return await perform(request: urlRequest, decoding: [ConversationResponse].self)
    }

    // MARK: - Private

    private func perform<T: Decodable>(request: URLRequest, decoding: T.Type) async -> Result<T, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(T.self, from: data))
            } catch {
                print("Decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print("Network error: \(error.localizedDescription)")
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockChatClient: ChatClientProtocol {
    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError> {
        return .success(.mock())
    }

    func createConversation(userId: String, type: String, coordinateId: String?, forceNew: Bool) async throws -> Result<ConversationResponse, HTTPError> {
        return .success(ConversationResponse(
            conversation_id: forceNew ? UUID().uuidString : "mock-conversation-id",
            type: type,
            coordinate_id: coordinateId,
            created_at: ISO8601DateFormatter().string(from: Date()),
            last_updated: ISO8601DateFormatter().string(from: Date()),
            message_count: 0,
            last_message_preview: nil
        ))
    }

    func fetchConversations(userId: String, limit: Int) async throws -> Result<[ConversationResponse], HTTPError> {
        let now = ISO8601DateFormatter().string(from: Date())
        let yesterday = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400))
        return .success([
            ConversationResponse(
                conversation_id: "mock-general-2",
                type: "general",
                coordinate_id: nil,
                created_at: now,
                last_updated: now,
                message_count: 5,
                last_message_preview: "シンプルなコーデのポイントを教えてください"
            ),
            ConversationResponse(
                conversation_id: "mock-coord-1",
                type: "coordinate",
                coordinate_id: "coord-abc",
                created_at: now,
                last_updated: now,
                message_count: 3,
                last_message_preview: "このコーデに合う靴は何ですか？"
            ),
            ConversationResponse(
                conversation_id: "mock-general-1",
                type: "general",
                coordinate_id: nil,
                created_at: yesterday,
                last_updated: yesterday,
                message_count: 8,
                last_message_preview: "秋のコーデに合うカラーは何ですか"
            )
        ])
    }

    func fetchMessages(conversationId: String, userId: String, limit: Int) async throws -> Result<ChatHistoryResponse, HTTPError> {
        return .success(ChatHistoryResponse(conversation_id: conversationId, messages: []))
    }

    func postWithHistory(conversationId: String, request: ChatWithHistoryRequest) async throws -> Result<ChatWithHistoryResponse, HTTPError> {
        let now = ISO8601DateFormatter().string(from: Date())
        return .success(ChatWithHistoryResponse(
            user_message: ChatMessageRecord(id: UUID().uuidString, text: request.question, is_user: true, created_at: now),
            ai_message: ChatMessageRecord(id: UUID().uuidString, text: "モックの返答です。", is_user: false, created_at: now)
        ))
    }
}
