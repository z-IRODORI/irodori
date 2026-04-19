//
//  ClosetResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/11.
//

import Foundation

struct ClosetResponse: Codable {
    let items: [ClosetItem]
}

struct ClosetItem: Codable, Identifiable, Hashable {
    let id: String
    let item_type: String
    let category: String?
    let color: String?
    let image_url: String?
    let date: String?

    // ClothingCategoryへの変換
    var clothingCategory: ClothingCategory {
        switch item_type {
        case "トップス":
            return .tops
        case "ボトムス":
            return .bottoms
//        case "靴", "シューズ":
//            return .shoes
//        case "アウター":
//            return .outer
        default:
            return .tops // デフォルトはトップス
        }
    }
}
