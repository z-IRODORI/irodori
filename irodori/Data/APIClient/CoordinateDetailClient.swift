//
//  CoordinateDetailClient.swift
//  irodori
//
//  Created by Claude on 2025/10/01.
//

import Foundation

protocol CoordinateDetailClientProtocol {
    func get(uid: String, targetDate: String) async throws -> Result<[CoordinateDetailResponse], Error>
}

final class CoordinateDetailClient: CoordinateDetailClientProtocol {
    func get(uid: String, targetDate: String) async throws -> Result<[CoordinateDetailResponse], Error> {
        let baseURL = "https://irodori.click"
        let endpoint = "api/coordinate/date/\(uid)/\(targetDate)"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode([CoordinateDetailResponse].self, from: data)
            return .success(response)
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}
