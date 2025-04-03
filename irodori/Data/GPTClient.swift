//
//  GPTClient.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/25.
//

import Foundation
import UIKit

// レスポンスの構造体
struct GPTResponse: Decodable {
    let result: String
}

struct ImageRequest: Encodable {
    let image_base64: String
}

final class GPTClient {
    func postImageToGPT(image: UIImage) async throws -> String {
        let url = URL(string: "https://irodori-api.onrender.com/coordinate-review")!

        // UIImageをJPEGデータに変換し、Base64エンコード
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        let base64String = jpegData.base64EncodedString()


        let requestBody = ImageRequest(image_base64: base64String)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode(GPTResponse.self, from: data)
            return response.result
        } catch {
            print(error.localizedDescription)
            return error.localizedDescription
        }
    }
}

