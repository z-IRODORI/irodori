//
//  UserResponse.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - User API Response Models

struct UserInfo: Codable {
    let id: String
    let cognito_id: String
    let email: String
    let name: String
    let icon_url: String
}

struct UsersResponse: Codable {
    let users: [UserInfo]
}

struct UserRegistrationResponse: Codable {
    let status: String
    let id: String
    let user_name: String
}