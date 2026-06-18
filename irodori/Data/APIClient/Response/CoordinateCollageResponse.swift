//
//  CoordinateCollageResponse.swift
//  irodori
//
//  POST /api/coordinate/collage のレスポンス。
//  複数コーデ画像から人物を切り抜いて 1 枚に合成したコラージュ画像を返す。
//

import Foundation

struct CoordinateCollageResponse: Decodable {
    let status: String
    let collage_id: String
    let collage_url: String       // Firebase Storage 公開 URL (本番)
    let collage_base64: String    // アップロード不可環境でのフォールバック (PNG base64)
    let image_count: Int
    let elapsed_ms: Int
}
