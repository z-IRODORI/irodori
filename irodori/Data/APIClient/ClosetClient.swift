//
//  ClosetClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/11.
//

import Foundation

protocol ClosetClientProtocol {
    func get(uid: String, itemType: String?) async throws -> Result<ClosetResponse, HTTPError>
}

final class ClosetClient: ClosetClientProtocol {
    func get(uid: String, itemType: String?) async throws -> Result<ClosetResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/closet"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // クエリパラメータを追加
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "user_id", value: uid)]
        if let itemType = itemType {
            queryItems.append(URLQueryItem(name: "item_type", value: itemType))
        }
        components.queryItems = queryItems
        request.url = components.url

        do {
            // URLSessionでリクエストを送信
            let (data, urlResponse) = try await URLSession.shared.data(for: request)

            // ステータスコードをチェック
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            // JSONレスポンスをデコード
            do {
                let response = try JSONDecoder().decode(ClosetResponse.self, from: data)
                return .success(response)
            } catch {
                print("Decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockClosetClient: ClosetClientProtocol {
    func get(uid: String, itemType: String?) async throws -> Result<ClosetResponse, HTTPError> {
        let mockItems = [
            ClosetItem(
                id: "550e8400-e29b-41d4-a716-446655440001",
                item_type: "トップス",
                category: "Tシャツ",
                color: "ホワイト",
                image_url: "https://storage.googleapis.com/bucket/items/user-123/tops/uuid1.jpg",
                date: "2026/02/11"
            ),
            ClosetItem(
                id: "550e8400-e29b-41d4-a716-446655440002",
                item_type: "ボトムス",
                category: "ワイドパンツ",
                color: "ブラック",
                image_url: "https://storage.googleapis.com/bucket/items/user-123/bottoms/uuid2.jpg",
                date: "2026/02/10"
            )
        ]
        return .success(ClosetResponse(items: mockItems))
    }
}
