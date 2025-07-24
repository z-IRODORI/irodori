//
//  CreateUserClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/24.
//

import Foundation

final class CreateUserClient {
    func post(createUserRequest: CreateUserRequest) async throws -> Result<CreateUserResponse, Error> {
        let baseURL = "https://irodori.click"
        let endpoint = "api/user"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        let requestBody = createUserRequest

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            print(data)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(CreateUserResponse.self, from: data)
            print(response)
            return .success(response)
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}


