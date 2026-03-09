//
//  DeleteCoordinateClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/03/08.
//

import Foundation

protocol DeleteCoordinateClientProtocol {
    func delete(uid: String, coordinateId: String) async throws -> Result<DeleteCoordinateResponse, HTTPError>
}

final class DeleteCoordinateClient: DeleteCoordinateClientProtocol {
    func delete(uid: String, coordinateId: String) async throws -> Result<DeleteCoordinateResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/coordinate/\(coordinateId)"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // クエリパラメータとしてuidを追加
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uid", value: uid)]
        request.url = components.url

        do {
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
                let response = try JSONDecoder().decode(DeleteCoordinateResponse.self, from: data)
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

final class MockDeleteCoordinateClient: DeleteCoordinateClientProtocol {
    func delete(uid: String, coordinateId: String) async throws -> Result<DeleteCoordinateResponse, HTTPError> {
        // モックは常に成功を返す
        return .success(.init(success: true, message: "削除しました", deleted_items_count: 1))
    }
}
