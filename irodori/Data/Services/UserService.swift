//
//  UserService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

protocol UserServiceProtocol: Sendable {
    func getAllUsers() async throws -> Result<[UserInfo], HTTPError>
    func createUser(_ request: UserRegistrationRequest) async throws -> Result<UserRegistrationResponse, HTTPError>
    func getUser(cognitoId: String) async throws -> Result<UserInfo, HTTPError>
}

final class UserService: UserServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func getAllUsers() async throws -> Result<[UserInfo], HTTPError> {
        let request = GetAllUsersRequest()
        return try await apiClient.request(request)
    }
    
    func createUser(_ request: UserRegistrationRequest) async throws -> Result<UserRegistrationResponse, HTTPError> {
        let apiRequest = CreateUserRequest(userRegistration: request)
        return try await apiClient.request(apiRequest)
    }
    
    func getUser(cognitoId: String) async throws -> Result<UserInfo, HTTPError> {
        let request = GetUserRequest(cognitoId: cognitoId)
        return try await apiClient.request(request)
    }
}