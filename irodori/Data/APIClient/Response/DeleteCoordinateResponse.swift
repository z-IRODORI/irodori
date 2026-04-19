//
//  DeleteCoordinateResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/03/08.
//

import Foundation

struct DeleteCoordinateResponse: Decodable {
    let success: Bool
    let message: String
    let deleted_items_count: Int
}
