//
//  CoordinateItem.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/21.
//

import Foundation

// MARK: - Legacy CoordinateItem (for backward compatibility)
struct CoordinateItem: Codable, Hashable {
    var id: Int
    var topsURL: String
    var pantsURL: String
}

// MARK: - API-Compatible CoordinateItem
struct APICoordinateItem: Codable {
    let id: String
    let coordinate_id: String
    let item_type: String
    let item_image_path: String?
}
