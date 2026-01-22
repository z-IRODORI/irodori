//
//  CoordinateRecommendClient.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation

protocol CoordinateRecommendClientProtocol {
    func post(
        gender: String,
        inputType: String,
        category: String,
        text: String,
        numOutfits: Int,
        numCandidates: Int
    ) async throws -> Result<CoordinateRecommendResponse, HTTPError>
}

final class CoordinateRecommendClient: CoordinateRecommendClientProtocol {
    func post(
        gender: String,
        inputType: String,
        category: String,
        text: String,
        numOutfits: Int,
        numCandidates: Int
    ) async throws -> Result<CoordinateRecommendResponse, HTTPError> {
        let url = URL(string: "https://irodori-api.onrender.com/coordinate-recommend")!

        let requestBody = CoordinateRecommendRequest(
            gender: gender,
            input_type: inputType,
            category: category,
            text: text,
            num_outfits: numOutfits,
            num_candidates: numCandidates
        )

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
                print("CoordinateRecommend API Status Code: \(statusCode)")
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            do {
                let response = try JSONDecoder().decode(CoordinateRecommendResponse.self, from: data)
                return .success(response)
            } catch {
                print("Decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print("Response error: \(error)")
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockCoordinateRecommendClient: CoordinateRecommendClientProtocol {
    func post(
        gender: String,
        inputType: String,
        category: String,
        text: String,
        numOutfits: Int,
        numCandidates: Int
    ) async throws -> Result<CoordinateRecommendResponse, HTTPError> {
        return .success(.mock())
    }
}

// テスト用: エラーを返すMockクライアント
final class MockErrorCoordinateRecommendClient: CoordinateRecommendClientProtocol {
    func post(
        gender: String,
        inputType: String,
        category: String,
        text: String,
        numOutfits: Int,
        numCandidates: Int
    ) async throws -> Result<CoordinateRecommendResponse, HTTPError> {
        return .failure(.unknownError)
    }
}
