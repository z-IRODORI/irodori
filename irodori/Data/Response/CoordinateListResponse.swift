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
}
