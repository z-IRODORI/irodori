//
//  GPTClient.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/25.
//

import Foundation
import UIKit

final class GPTClient {
    func postImageToGPT(image: UIImage, outingPurposeType: OutingPurposeType) async throws -> Result<CoordinateReview, Error> {
//        let baseURL = "https://nfzoiluhpi.execute-api.ap-northeast-1.amazonaws.com/prod/"
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "coordinate-review"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        // UIImageをJPEGデータに変換し、Base64エンコード
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        let base64String = jpegData.base64EncodedString()


        let requestBody = CoordinateReviewRequest(
            image_base64: base64String,
            outing_purpose_id: outingPurposeType.number
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(CoordinateReview.self, from: data)
            return .success(response)
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}

