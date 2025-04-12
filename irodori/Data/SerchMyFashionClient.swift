//
//  SerchMyFashionClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/04.
//

import UIKit

final class SerchMyFashionClient {
    func postImage(image: UIImage) async throws -> PredictResponse? {
        let baseURL = "https://irodori.click"
        let endpoint = "predict"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        // UIImageをJPEGデータに変換し、Base64エンコード
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        let base64String = jpegData.base64EncodedString()


        let requestBody = PredictRequest(image_base64: base64String)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(PredictResponse.self, from: data)
            return response
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
}


