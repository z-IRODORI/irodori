//
//  AnalyzeRecentCoordinateClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/12.
//

import Foundation

protocol AnalyzeRecentCoordinateClientProtocol {
    func post(uid: String, targetDays: Int) async throws -> Result<AnalyzeRecentCoordinateResponse, HTTPError>
}

final class AnalyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol {
    func post(uid: String, targetDays: Int = 7) async throws -> Result<AnalyzeRecentCoordinateResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/analyze-recent-coordinate"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        let requestBody = AnalyzeRecentCoordinateRequest(uid: uid, target_days: targetDays)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            return .failure(.badRequest)
        }

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
                let response = try JSONDecoder().decode(AnalyzeRecentCoordinateResponse.self, from: data)
                return .success(response)
            } catch {
                print("Decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockAnalyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol {
    func post(uid: String, targetDays: Int) async throws -> Result<AnalyzeRecentCoordinateResponse, HTTPError> {
        let mockResponse = AnalyzeRecentCoordinateResponse(
            analyze_recent_coordinate: "カジュアルを基調としつつ、モノトーンやシンプルなアイテムを好む傾向が見られます。ミニマルでスマートな印象を大切にしているようですね！"
        )
        return .success(mockResponse)
    }
}
