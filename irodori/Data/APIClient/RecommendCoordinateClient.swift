//
//  RecommendCoordinateClient.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/09/02.
//

import Foundation

protocol RecommendCoordinateClientProtocol {
    func post(gender: String) async throws -> Result<RecommendCoordinateResponse, HTTPError>
}

final class RecommendCoordinateClient: RecommendCoordinateClientProtocol {
    func post(gender: String) async throws -> Result<RecommendCoordinateResponse, HTTPError> {
        let url = URL(string: "https://irodori-api.onrender.com/recommend-coordinates")!
        
        let requestBody = RecommendCoordinateRequest(gender: gender)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            return .failure(.badRequest)
        }
        
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print(statusCode)
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            
            do {
                let response = try JSONDecoder().decode(RecommendCoordinateResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockRecommendCoordinateClient: RecommendCoordinateClientProtocol {
    func post(gender: String) async throws -> Result<RecommendCoordinateResponse, HTTPError> {
        return .success(.mock())
    }
}

// テスト用: アフィリエイトデータなしのコーディネートのみを返すMockクライアント
final class MockEmptyAffiliateRecommendCoordinateClient: RecommendCoordinateClientProtocol {
    func post(gender: String) async throws -> Result<RecommendCoordinateResponse, HTTPError> {
        let emptyAffiliateCoordinates = RecommendCoordinateResponse(
            coordinates: [
                RecommendCoordinate(
                    id: 10,
                    image_url: "https://i.pinimg.com/736x/test/test1.jpg",
                    pin_url_guess: "https://pinterest.com/pin/test1",
                    coordinate_review: "アフィリエイトデータなしのテストコーディネート",
                    tops_categorize: "シャツ 無地 レギュラー ブルー",
                    bottoms_categorize: "パンツ 無地 スリム ベージュ",
                    affiliate_tops: [],
                    affiliate_bottoms: []
                )
            ],
            recommend_reasons: "recommend_reasons",
            genres: [
                Genre(genre: "test", count: 1)
            ]
        )
        return .success(emptyAffiliateCoordinates)
    }
}

// テスト用: エラーを返すMockクライアント
final class MockErrorRecommendCoordinateClient: RecommendCoordinateClientProtocol {
    func post(gender: String) async throws -> Result<RecommendCoordinateResponse, HTTPError> {
        return .failure(.unknownError)
    }
}
