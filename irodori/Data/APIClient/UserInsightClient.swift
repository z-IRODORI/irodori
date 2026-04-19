//
//  UserInsightClient.swift
//  irodori
//
//  Created by Claude on 2026/03/12.
//

import Foundation

protocol UserInsightClientProtocol {
    func get(uid: String) async throws -> Result<UserInsightResponse, HTTPError>
}

final class UserInsightClient: UserInsightClientProtocol {
    func get(uid: String) async throws -> Result<UserInsightResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/user-insight"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "userid", value: uid)
        ]
        request.url = components.url

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.responseError)
            }

            if httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }

            let decodedResponse = try JSONDecoder().decode(UserInsightResponse.self, from: data)
            return .success(decodedResponse)
        } catch is DecodingError {
            return .failure(.decodeError)
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

final class MockUserInsightClient: UserInsightClientProtocol {
    func get(uid: String) async throws -> Result<UserInsightResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return .success(.mock())
    }
}
