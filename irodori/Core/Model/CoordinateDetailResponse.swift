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
    }

    struct CoordinateItem: Codable {
        let id: String
        let coordinate_id: String
        let item_type: String
        let item_image_path: String
    }
}
