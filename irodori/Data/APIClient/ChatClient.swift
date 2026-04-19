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
        print("=== ChatClient POST Request ===")
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "chat"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // タイムアウトを延長（デフォルト60秒→120秒）
        request.timeoutInterval = 120

        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
            print("Request body size: \(request.httpBody?.count ?? 0) bytes")
        } catch {
            print("Failed to encode request: \(error)")
            throw error
        }

        do {
            print("Sending request to: \(url)")
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            print("Received response, data size: \(data.count) bytes")

            // ステータスコードをチェック
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print("HTTP Status Code: \(statusCode)")
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            // レスポンスの内容を確認
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(responseString)")
            }

            // JSONレスポンスをデコード
            do {
                let response = try JSONDecoder().decode(ChatResponse.self, from: data)
                print("Successfully decoded response")
                print("===============================")
                return .success(response)
            } catch {
                print("Decode error: \(error)")
                print("===============================")
                return .failure(.decodeError)
            }
        } catch {
            print("Network error: \(error.localizedDescription)")
            print("===============================")
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
