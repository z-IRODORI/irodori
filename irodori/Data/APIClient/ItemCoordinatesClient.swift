//
//  ItemCoordinatesClient.swift
//  irodori
//

import Foundation

protocol ItemCoordinatesClientProtocol {
    /// アイテム詳細 + そのアイテムを使ったコーデ一覧を取得する
    func get(itemId: String, uid: String) async throws -> Result<ItemCoordinatesResponse, HTTPError>
}

final class ItemCoordinatesClient: ItemCoordinatesClientProtocol {
    func get(itemId: String, uid: String) async throws -> Result<ItemCoordinatesResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/item/\(itemId)/coordinates"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.badRequest) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(ItemCoordinatesResponse.self, from: data)
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

final class MockItemCoordinatesClient: ItemCoordinatesClientProtocol {
    func get(itemId: String, uid: String) async throws -> Result<ItemCoordinatesResponse, HTTPError> {
        return .success(.mock())
    }
}
