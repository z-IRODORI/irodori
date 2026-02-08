//
//  HomeClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

protocol HomeClientProtocol {
    func get(uid: String) async throws -> Result<HomeResponse, HTTPError>
}

final class HomeClient: HomeClientProtocol {
    func get(uid: String) async throws -> Result<HomeResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/home"
        let url = URL(string: "\(baseURL)/\(endpoint)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // クエリパラメータとしてuidを追加
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: uid)
        ]
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
                let response = try JSONDecoder().decode(HomeResponse.self, from: data)
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
    func get(uid: String) async throws -> Result<HomeResponse, HTTPError> {
        return .success(.mock())
    }
}
