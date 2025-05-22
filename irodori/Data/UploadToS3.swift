//
//  UploadToS3.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/22.
//

import UIKit

final class UploadToS3 {
    func uploadImageToS3(image: UIImage, url: URL) async throws -> Bool {
        let fixedImage = image.fixedOrientation()
        // 画像データをJPEG形式で取得（圧縮率0.8）
        guard let imageData = fixedImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageConversionError", code: -1, userInfo: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return true
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return false
        }
    }
}
