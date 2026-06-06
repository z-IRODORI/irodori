//
//  ClosetBridgeClient.swift
//  irodori
//
//  クローゼット買い足し提案APIクライアント
//  GET /api/home/closet-bridge
//

import Foundation

protocol ClosetBridgeClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<ClosetBridgeResponse, HTTPError>
}

final class ClosetBridgeClient: ClosetBridgeClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func get(uid: String, gender: Gender) async throws -> Result<ClosetBridgeResponse, HTTPError> {
        let endpoint = "api/home/closet-bridge"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "gender", value: gender.apiValue),
        ]
        if let prefectureCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue),
           !prefectureCode.isEmpty {
            items.append(URLQueryItem(name: "prefecture_code", value: prefectureCode))
        }
        components.queryItems = items
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // closet-bridge は Gemini×2 + Yahoo 検索 + Render コールドスタートで時間がかかるため長めに確保
        request.timeoutInterval = 60

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(ClosetBridgeResponse.self, from: data)
                return .success(response)
            } catch {
                print("[ClosetBridgeClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockClosetBridgeClient: ClosetBridgeClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<ClosetBridgeResponse, HTTPError> {
        return .success(.mock())
    }
}
