//
//  CoordinateListClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/17.
//

import Foundation

final class CoordinateListClient {
    func get(uid: String, year: Int, month: Int) async throws -> Result<CoordinateListResponse, Error> {
//        let baseURL = "https://nfzoiluhpi.execute-api.ap-northeast-1.amazonaws.com/prod/"
        let baseURL = "https://irodori.click"
        let endpoint = "api/coordinate/list/\(uid)"
        let url = URL(string: "\(baseURL)/\(endpoint)?user_id=\(uid)&year=\(year)&month=\(month)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(CoordinateListResponse.self, from: data)
            return .success(response)
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}
