//
//  RecentCoordinate.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct RecentCoordinate: Codable, Hashable, Equatable {
    var id: String
    var date: String
    var image_url: String              // 撮影画像URL
    var cutout_image_url: String?      // 人物切り取り後画像URL
    var display_type: String?          // "captured" | "cutout"

    // 後方互換性のため、古いフィールド名もサポート。
    // home は cutout_image_url、fashion_review は cutout_image_path を返すため両方受ける。
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case image_url
        case coodinate_image_path
        case cutout_image_url
        case cutout_image_path
        case display_type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)

        // image_urlを優先的に読み取り、なければcoodinate_image_pathを使用
        if let imageUrl = try? container.decode(String.self, forKey: .image_url) {
            image_url = imageUrl
        } else {
            image_url = try container.decode(String.self, forKey: .coodinate_image_path)
        }
        let byUrl = (try? container.decodeIfPresent(String.self, forKey: .cutout_image_url)) ?? nil
        let byPath = (try? container.decodeIfPresent(String.self, forKey: .cutout_image_path)) ?? nil
        cutout_image_url = byUrl ?? byPath
        display_type = (try? container.decodeIfPresent(String.self, forKey: .display_type)) ?? nil
    }

    init(id: String, date: String, image_url: String, cutout_image_url: String? = nil, display_type: String? = nil) {
        self.id = id
        self.date = date
        self.image_url = image_url
        self.cutout_image_url = cutout_image_url
        self.display_type = display_type
    }

    // CodingKeys に後方互換キー (coodinate_image_path 等) が含まれるため encode は明示定義
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(image_url, forKey: .image_url)
        try container.encodeIfPresent(cutout_image_url, forKey: .cutout_image_url)
        try container.encodeIfPresent(display_type, forKey: .display_type)
    }

    /// 一覧に出す画像URL (display_type に応じて撮影/切り取りを選択)。
    var displayImageURL: String {
        CoordinateImageResolver.url(captured: image_url, cutout: cutout_image_url, displayType: display_type) ?? image_url
    }
}
