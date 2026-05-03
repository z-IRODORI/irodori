//
//  DeleteClosetItemClient.swift
//  irodori
//

import Foundation

protocol DeleteClosetItemClientProtocol {
    func delete(uid: String, itemId: String) async throws -> Result<DeleteClosetItemResponse, HTTPError>
}

final class DeleteClosetItemClient: DeleteClosetItemClientProtocol {
    func delete(uid: String, itemId: String) async throws -> Result<DeleteClosetItemResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let url = URL(string: "\(baseURL)/api/items/\(itemId)")!

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uid", value: uid)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)

            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }

            do {
                let response = try JSONDecoder().decode(DeleteClosetItemResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockDeleteClosetItemClient: DeleteClosetItemClientProtocol {
    func delete(uid: String, itemId: String) async throws -> Result<DeleteClosetItemResponse, HTTPError> {
        return .success(.init(success: true, message: "削除しました"))
    }
}
