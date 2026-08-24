//
//  TryOnResponse.swift
//  irodori
//

import Foundation

/// POST /api/try-on のレスポンス。
/// 結果画像はサーバに保存されず base64 で直接返る (TryOnCache でローカル保持)。
struct TryOnResponse: Codable {
    let status: String
    let image_base64: String
    let mime_type: String
    let model: String
    let generation_ms: Int

    var imageData: Data? {
        Data(base64Encoded: image_base64)
    }
}
