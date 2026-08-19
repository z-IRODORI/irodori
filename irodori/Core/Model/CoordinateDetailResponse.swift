//
//  CoordinateDetailResponse.swift
//  irodori
//
//  Created by Claude on 2025/10/01.
//

import Foundation

struct CoordinateDetailResponse: Codable {
    let current_coordinate: CurrentCoordinate
    let items: [CoordinateItem]
    let ai_catchphrase: String
    let ai_review_comment: String

    struct CurrentCoordinate: Codable {
        let id: String
        let date: String
        let coodinate_image_path: String
        let cutout_image_path: String?
        let display_type: String?

        /// 一覧/詳細に出す画像URL (display_type に応じて撮影/切り取りを選択)。
        var displayImageURL: String {
            CoordinateImageResolver.url(captured: coodinate_image_path, cutout: cutout_image_path, displayType: display_type) ?? coodinate_image_path
        }
    }

    struct CoordinateItem: Codable {
        let id: String
        let coordinate_id: String
        let item_type: String
        let item_image_path: String
        /// v2: 画像の由来 (generated/cached/crop/coordinate)。
        /// "pending" はバックグラウンド生成中 (ポーリングの継続判定に使う)
        var image_source: String? = nil
    }
}
