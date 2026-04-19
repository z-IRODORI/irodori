//
//  RecentCoordinate.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct RecentCoordinate: Decodable, Hashable, Equatable {
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
}
