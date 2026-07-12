//
//  CoordinateListResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/17.
//

import Foundation

struct CoordinateListResponse: Decodable {
    var year: Int
    var month: Int
    var day: Int
    var id: String?
    var coodinate_image_path: String?
    var cutout_image_path: String?
    var display_type: String?

    /// 一覧に出す画像URL (display_type に応じて撮影/切り取りを選択)。
    var displayImageURL: String? {
        CoordinateImageResolver.url(captured: coodinate_image_path, cutout: cutout_image_path, displayType: display_type)
    }
}
