//
//  UserRequest.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - User API Request Models

struct UserRegistrationRequest: Codable {
    let cognito_id: String
    let user_name: String
    let email: String
    let icon_url: String
}