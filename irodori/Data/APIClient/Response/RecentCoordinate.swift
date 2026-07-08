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
    var image_url: String

    // 後方互換性のため、古いフィールド名もサポート
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case image_url
        case coodinate_image_path
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
    }

    init(id: String, date: String, image_url: String) {
        self.id = id
        self.date = date
        self.image_url = image_url
    }

    // CodingKeys に後方互換キー (coodinate_image_path) が含まれるため encode は明示定義
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(image_url, forKey: .image_url)
    }
}
