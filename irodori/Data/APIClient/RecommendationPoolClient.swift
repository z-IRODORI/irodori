//
//  RecommendationPoolClient.swift
//  irodori
//
//  GET /api/recommendation-pool/{pool_id}: 単体の pool アイテムを取得.
//  お気に入り画面 (kind=pool) のタップで完全データを表示するために使う.
//

import Foundation

protocol RecommendationPoolClientProtocol {
    func get(poolId: String, uid: String) async throws -> Result<DailyRecommendationItem, HTTPError>
}

final class RecommendationPoolClient: RecommendationPoolClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func get(poolId: String, uid: String) async throws -> Result<DailyRecommendationItem, HTTPError> {
        guard let encoded = poolId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return .failure(.responseError)
        }
        var components = URLComponents(string: "\(baseURL)/api/recommendation-pool/\(encoded)")!
        if !uid.isEmpty {
            components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        }
        guard let url = components.url else { return .failure(.responseError) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(DailyRecommendationItem.self, from: data)
                return .success(response)
            } catch {
                print("[RecommendationPoolClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}
