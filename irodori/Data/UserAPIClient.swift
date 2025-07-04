//
//  UserAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import Combine

// MARK: - UserAPIClient Protocol

protocol UserAPIClientProtocol {
    func getAllUsers() -> AnyPublisher<[UserInfo], APIError>
    func createUser(_ request: UserRegistrationRequest) -> AnyPublisher<UserRegistrationResponse, APIError>
    func getUser(cognitoId: String) -> AnyPublisher<UserInfo, APIError>
}

// MARK: - UserAPIClient Implementation

class UserAPIClient: UserAPIClientProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func getAllUsers() -> AnyPublisher<[UserInfo], APIError> {
        let endpoint = APIEndpoint(
            path: "/api/user",
            method: .GET
        )
        
        return apiClient.request(endpoint, responseType: [UserInfo].self)
    }
    
    func createUser(_ request: UserRegistrationRequest) -> AnyPublisher<UserRegistrationResponse, APIError> {
        let endpoint = APIEndpoint(
            path: "/api/user",
            method: .POST,
            body: [
                "cognito_id": request.cognito_id,
                "user_name": request.user_name,
                "email": request.email,
                "icon_url": request.icon_url
            ]
        )
        
        return apiClient.request(endpoint, responseType: UserRegistrationResponse.self)
    }
    
    func getUser(cognitoId: String) -> AnyPublisher<UserInfo, APIError> {
        let endpoint = APIEndpoint(
            path: "/api/user/\(cognitoId)",
            method: .GET
        )
        
        return apiClient.request(endpoint, responseType: UserInfo.self)
    }
}