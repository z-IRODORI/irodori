//
//  DeleteUserClient.swift
//  irodori
//
//  DELETE /api/user を呼び、アカウント (サーバ上の全データ + Firebase Auth ユーザー) を完全に削除する.
//  なりすまし防止のため Firebase ID トークンを Authorization ヘッダで送る.
//

import Foundation

struct DeleteUserResponse: Decodable {
    let status: String
}

protocol DeleteUserClientProtocol {
    func delete(userId: String, idToken: String) async throws -> Result<DeleteUserResponse, HTTPError>
}

final class DeleteUserClient: DeleteUserClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func delete(userId: String, idToken: String) async throws -> Result<DeleteUserResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/user")!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        guard let url = components.url else {
            return .failure(.responseError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120   // Render のコールドスタート + 全データ削除を待つ

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(DeleteUserResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}

final class MockDeleteUserClient: DeleteUserClientProtocol {
    func delete(userId: String, idToken: String) async throws -> Result<DeleteUserResponse, HTTPError> {
        try? await Task.sleep(for: .seconds(0.3))
        return .success(DeleteUserResponse(status: "deleted"))
    }
}
