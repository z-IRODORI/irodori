//
//  FashionReviewClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import UIKit

protocol FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError>
}

final class FashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/fashion_review"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        // UIImageをJPEGデータに変換
        guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
            return .failure(.badRequest)
        }

        let fashionReviewRequest = FashionReviewRequest(user_id: uid, user_token: uid, file: jpegData)
        let requestParameters: [String: Any] = fashionReviewRequest.createParameters()
        let (headers, body) = HTTP.createMultiPartPost(parameters: requestParameters)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // ヘッダーの設定
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        // Bodyの設定
        request.httpBody = body

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
                let response = try JSONDecoder().decode(FashionReviewResponse.self, from: data)
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

final class MockFashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError> {
        return .success(.mock())
    }
}
