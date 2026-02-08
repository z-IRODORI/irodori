//
//  ChatClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/09.
//

import Foundation

protocol ChatClientProtocol {
    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError>
}

final class ChatClient: ChatClientProtocol {
    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "chat"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(chatRequest)

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)

            // ステータスコードをチェック
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            print(data)
            // JSONレスポンスをデコード
            do {
                let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockChatClient: ChatClientProtocol {
    func post(chatRequest: ChatRequest) async throws -> Result<ChatResponse, HTTPError> {
        return .success(.mock())
    }
}
