//
//  MockServices.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import UIKit

// MARK: - MockUserService

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

// MARK: - MockCoordinateService

final class MockCoordinateService: CoordinateServiceProtocol {
    private let mockAPIClient: MockAPIClient
    
    init(mockAPIClient: MockAPIClient = MockAPIClient()) {
        self.mockAPIClient = mockAPIClient
    }
    
    func getCoordinates(userId: String, page: Int) async throws -> Result<[DailyCoordinate], HTTPError> {
        let request = GetCoordinatesRequest(userId: userId, page: page)
        return try await mockAPIClient.request(request)
    }
    
    func createCoordinate(_ request: CoordinateRequest) async throws -> Result<CoordinateResponse, HTTPError> {
        let apiRequest = CreateCoordinateRequest(coordinateRequest: request)
        return try await mockAPIClient.request(apiRequest)
    }
    
    func getCoordinateItems(coordinateId: String) async throws -> Result<[APICoordinateItem], HTTPError> {
        let request = GetCoordinateItemsRequest(coordinateId: coordinateId)
        return try await mockAPIClient.request(request)
    }
}

// MARK: - MockFashionReviewService

final class MockFashionReviewService: FashionReviewServiceProtocol {
    private let mockAPIClient: MockAPIClient
    
    init(mockAPIClient: MockAPIClient = MockAPIClient()) {
        self.mockAPIClient = mockAPIClient
    }
    
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int) async throws -> Result<APIFashionReviewResponse, HTTPError> {
        let request = SubmitFashionReviewRequest(
            userId: userId,
            userToken: userToken,
            image: image,
            days: days
        )
        return try await mockAPIClient.request(request)
    }
}