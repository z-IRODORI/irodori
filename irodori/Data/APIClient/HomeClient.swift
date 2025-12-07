//
//  HomeClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/04.
//

import Foundation

protocol HomeClientProtocol {
    func post(homeRequest: HomeRequest) async throws -> Result<HomeResponse, HTTPError>
}

final class HomeClient: HomeClientProtocol {
    func post(homeRequest: HomeRequest) async throws -> Result<HomeResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "chat"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(homeRequest)

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
                let response = try JSONDecoder().decode(HomeResponse.self, from: data)
                print(response.answer)
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

final class MockHomeClient: HomeClientProtocol {
    func post(homeRequest: HomeRequest) async throws -> Result<HomeResponse, HTTPError> {
        return .success(.mock())
    }
}

