//
//  UserRequests.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - Get All Users Request

struct GetAllUsersRequest: APIRequestProtocol {
    typealias Response = [UserInfo]
    
    let path: String = "/api/user"
    let method: HTTPMethod = .GET
}

// MARK: - Create User Request

struct CreateUserRequest: JSONRequestProtocol {
    typealias Response = UserRegistrationResponse
    typealias RequestBody = UserRegistrationRequest
    
    let path: String = "/api/user"
    let method: HTTPMethod = .POST
    let requestBody: UserRegistrationRequest?
    
    init(userRegistration: UserRegistrationRequest) {
        self.requestBody = userRegistration
    }
}

// MARK: - Get User Request

struct GetUserRequest: APIRequestProtocol {
    typealias Response = UserInfo
    
    let path: String
    let method: HTTPMethod = .GET
    
    init(cognitoId: String) {
        self.path = "/api/user/\(cognitoId)"
    }
}