//
//  FashionReviewClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import UIKit

protocol FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, Error>
}

final class FashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, Error> {
        let baseURL = "https://irodori.click"
        let endpoint = "v1/fashion-review"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        // UIImageをJPEGデータに変換
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }

        let fashionReviewRequest = FashionReviewRequest(user_id: uid, user_token: UUID().uuidString, file: jpegData)
        let requestParameters: [String: Any] = fashionReviewRequest.createParameters()
        let (headers, body) = createMultiPartPost(parameters: requestParameters)

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
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(FashionReviewResponse.self, from: data)
            return .success(response)
        } catch {
            print(error.localizedDescription)
            return .failure(error)
        }
    }

    private func createMultiPartPost(parameters: [String: Any]) -> (headers: [String:String], body: Data) {
        let uniqueId = UUID().uuidString
        let boundary = "---------------------------\(uniqueId)"

        let header = [
            "Content-Type" : "multipart/form-data; boundary=\(boundary)"
        ]

        var body = Data()

        let boundaryText = "--\(boundary)\r\n"

        for param in parameters {
            switch param.value {
            case let imageData as Data:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"; filename=\"\(uniqueId).jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            case let string as String:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(string.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            case let value as Any:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(String(describing: value).data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return (header, body)
    }
}

// MARK: - Mock

final class MockFashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, any Error> {
        return .success(.mock())
    }
}
