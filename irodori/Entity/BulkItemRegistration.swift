//
//  BulkItemRegistration.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/15.
//

import Foundation

struct BulkItemMetadata: Codable {
    let index: Int
    let gender: String?
    let main_category: String?
    let sub_category: String?
    let color: String?
    let item_type: String?
    let category: String?
    let coordinate_id: String?
}

struct RegisteredItem: Codable {
    let id: String
    let storage_url: String
    // User closet item fields (standard item fields removed as they're now user items)
    let gender: String?
    let main_category: String?
    let sub_category: String?
    let color: String?
    let item_type: String?
    let category: String?
    let coordinate_id: String?
    let created_at: String
}

struct BulkItemError: Codable {
    let index: Int
    let error: String
}

struct BulkItemRegistrationResponse: Codable {
    let status: String
    let total_count: Int
    let success_count: Int
    let failed_count: Int
    let items: [RegisteredItem]
    let errors: [BulkItemError]
}
