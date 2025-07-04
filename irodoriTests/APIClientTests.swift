//
//  APIClientTests.swift
//  irodoriTests
//
//  Created by Claude on 2025/07/04.
//

import XCTest
@testable import irodori

final class APIClientTests: XCTestCase {
    private var mockAPIClient: MockAPIClient!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
    }
    
    override func tearDownWithError() throws {
        mockAPIClient = nil
    }
    
    // MARK: - Success Tests
    
    func testGetAllUsersRequestSuccess() async throws {
        let request = GetAllUsersRequest()
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success(let users):
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users.first?.name, "Test User")
        case .failure:
            XCTFail("Request should succeed")
        }
    }
    
    func testCreateUserRequestSuccess() async throws {
        let userRequest = UserRegistrationRequest(
            cognito_id: "test123",
            user_name: "Test User",
            email: "test@example.com",
            icon_url: "https://example.com/icon.jpg"
        )
        let request = CreateUserRequest(userRegistration: userRequest)
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.status, "success")
            XCTAssertEqual(response.user_name, "Test User")
        case .failure:
            XCTFail("Request should succeed")
        }
    }
    
    func testGetCoordinatesRequestSuccess() async throws {
        let request = GetCoordinatesRequest(userId: "user123", page: 0)
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success(let coordinates):
            XCTAssertEqual(coordinates.count, 1)
            XCTAssertEqual(coordinates.first?.id, "coord123")
        case .failure:
            XCTFail("Request should succeed")
        }
    }
    
    func testSubmitFashionReviewRequestSuccess() async throws {
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        let request = SubmitFashionReviewRequest(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.current_coordinate.id, "coord123")
            XCTAssertEqual(response.ai_comment, "素敵なコーディネートですね！")
        case .failure:
            XCTFail("Request should succeed")
        }
    }
    
    // MARK: - Error Tests
    
    func testRequestWithNetworkError() async throws {
        let request = GetAllUsersRequest()
        mockAPIClient.setError(for: GetAllUsersRequest.self, error: .networkError)
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success:
            XCTFail("Request should fail")
        case .failure(let error):
            XCTAssertEqual(error, .networkError)
        }
    }
    
    func testRequestWithUnauthorizedError() async throws {
        let request = GetUserRequest(cognitoId: "test123")
        mockAPIClient.setError(for: GetUserRequest.self, error: .unauthorized)
        
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success:
            XCTFail("Request should fail")
        case .failure(let error):
            XCTAssertEqual(error, .unauthorized)
        }
    }
    
    // MARK: - Custom Response Tests
    
    func testCustomMockResponse() async throws {
        let customUser = UserInfo(
            id: "custom123",
            cognito_id: "custom_cognito",
            email: "custom@example.com",
            name: "Custom User",
            icon_url: "https://custom.com/icon.jpg"
        )
        
        mockAPIClient.setResponse(for: GetUserRequest.self, response: customUser)
        
        let request = GetUserRequest(cognitoId: "test123")
        let result = try await mockAPIClient.request(request)
        
        switch result {
        case .success(let user):
            XCTAssertEqual(user.name, "Custom User")
            XCTAssertEqual(user.email, "custom@example.com")
        case .failure:
            XCTFail("Request should succeed")
        }
    }
}