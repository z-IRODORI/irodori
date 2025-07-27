//
//  CreateUserResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/24.
//

import Foundation

struct CreateUserResponse: Codable {
    let id: String
    let user_name: String
    let year: Int
    let month: Int
    let day: Int
    let gender: Int
}
