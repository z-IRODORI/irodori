//
//  CreateUserRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/24.
//

import Foundation

struct CreateUserRequest: Encodable {
    let id: String
    let cognito_id: String
    let user_name: String
    let email: String = ""
    let icon_url: String = ""
    let year: Int
    let month: Int
    let day: Int
    let gender: Int   // 男性:0, 女性:1, その他:2
}
