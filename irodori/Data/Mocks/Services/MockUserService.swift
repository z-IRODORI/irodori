//
//  MockUserService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

final class MockUserService: UserServiceProtocol {
    private let mockAPIClient: MockAPIClient
    
    init(mockAPIClient: MockAPIClient = MockAPIClient()) {
        self.mockAPIClient = mockAPIClient
    }
    
    func getAllUsers() async throws -> Result<[UserInfo], HTTPError> {
        let request = GetAllUsersRequest()
        return try await mockAPIClient.request(request)
    }
    
    func createUser(_ request: UserRegistrationRequest) async throws -> Result<UserRegistrationResponse, HTTPError> {
        let apiRequest = CreateUserRequest(userRegistration: request)
        return try await mockAPIClient.request(apiRequest)
    }
    
    func getUser(cognitoId: String) async throws -> Result<UserInfo, HTTPError> {
        let request = GetUserRequest(cognitoId: cognitoId)
        return try await mockAPIClient.request(request)
    }
}

// MARK: - Convenience Methods for Testing

extension MockUserService {
    func setSuccessResponse(for method: UserServiceMethod, data: Any) {
        switch method {
        case .getAllUsers:
            mockAPIClient.setResponse(for: GetAllUsersRequest.self, response: data)
        case .createUser:
            mockAPIClient.setResponse(for: CreateUserRequest.self, response: data)
        case .getUser:
            mockAPIClient.setResponse(for: GetUserRequest.self, response: data)
        }
    }
    
    func setErrorResponse(for method: UserServiceMethod, error: HTTPError) {
        switch method {
        case .getAllUsers:
            mockAPIClient.setError(for: GetAllUsersRequest.self, error: error)
        case .createUser:
            mockAPIClient.setError(for: CreateUserRequest.self, error: error)
        case .getUser:
            mockAPIClient.setError(for: GetUserRequest.self, error: error)
        }
    }
}

enum UserServiceMethod {
    case getAllUsers
    case createUser
    case getUser
}