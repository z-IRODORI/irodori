//
//  CoordinateListResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/17.
//

import Foundation

struct CoordinateListResponse: Decodable {
    var items: [Item]

    struct Item: Decodable {
        var date: String
        var id: String?
        var coodinate_image_path: String?
    }
}
