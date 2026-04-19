//
//  FashionTypeClient.swift
//  irodori
//
//  Created by Claude on 2026/03/09.
//

import Foundation

protocol FashionTypeClientProtocol {
    func post(request: FashionTypeRequest) async throws -> Result<FashionTypeResponse, HTTPError>
}

final class FashionTypeClient: FashionTypeClientProtocol {
    func post(request: FashionTypeRequest) async throws -> Result<FashionTypeResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/fashion-type"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)

            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            do {
                let response = try JSONDecoder().decode(FashionTypeResponse.self, from: data)
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

final class MockFashionTypeClient: FashionTypeClientProtocol {
    func post(request: FashionTypeRequest) async throws -> Result<FashionTypeResponse, HTTPError> {
        // 模擬的な遅延
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        return .success(.mock())
    }
}
