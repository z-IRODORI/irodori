//
//  UserMockData.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - UserInfo Mock Data

extension UserInfo {
    static func mockData() -> UserInfo {
        return UserInfo(
            id: "user123",
            cognito_id: "cognito123",
            email: "test@example.com",
            name: "Test User",
            icon_url: "https://example.com/icon.jpg"
        )
    }
    
    static func mockDataList(count: Int = 3) -> [UserInfo] {
        return (1...count).map { index in
            UserInfo(
                id: "user\(index)",
                cognito_id: "cognito\(index)",
                email: "user\(index)@example.com",
                name: "Test User \(index)",
                icon_url: "https://example.com/icon\(index).jpg"
            )
        }
    }
}

// MARK: - UserRegistrationResponse Mock Data

extension UserRegistrationResponse {
    static func mockData() -> UserRegistrationResponse {
        return UserRegistrationResponse(
            status: "success",
            id: "user123",
            user_name: "Test User"
        )
    }
    
    static func mockErrorData() -> UserRegistrationResponse {
        return UserRegistrationResponse(
            status: "error",
            id: "",
            user_name: ""
        )
    }
}