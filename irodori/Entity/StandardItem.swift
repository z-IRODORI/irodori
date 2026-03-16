//
//  StandardItem.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import Foundation

struct StandardItem: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let storage_url: String
    let main_category: String
    let sub_category: String
    let color: String
    let gender: String
    let is_standard: Bool
    let file_size: Int
    let uploaded_at: String?
}

struct StandardItemFilters: Codable {
    let gender: String?
    let main_category: String?
    let sub_category: String?
    let color: String?
    let limit: Int?
}

struct StandardItemsResponse: Codable {
    let status: String
    let total_count: Int
    let items: [StandardItem]
    let filters: StandardItemFilters?
}
