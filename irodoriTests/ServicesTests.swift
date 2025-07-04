//
//  ServicesTests.swift
//  irodoriTests
//
//  Created by Claude on 2025/07/04.
//

import XCTest
@testable import irodori

// MARK: - UserService Tests

final class UserServiceTests: XCTestCase {
    private var userService: UserService!
    private var mockAPIClient: MockAPIClient!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        userService = UserService(apiClient: mockAPIClient)
    }
    
    override func tearDownWithError() throws {
        userService = nil
        mockAPIClient = nil
    }
    
    func testGetAllUsersSuccess() async throws {
        let result = try await userService.getAllUsers()
        
        switch result {
        case .success(let users):
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users.first?.email, "test@example.com")
        case .failure:
            XCTFail("Get all users should succeed")
        }
    }
    
    func testCreateUserSuccess() async throws {
        let request = UserRegistrationRequest(
            cognito_id: "test123",
            user_name: "Test User",
            email: "test@example.com",
            icon_url: "https://example.com/icon.jpg"
        )
        
        let result = try await userService.createUser(request)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.status, "success")
            XCTAssertEqual(response.user_name, "Test User")
        case .failure:
            XCTFail("Create user should succeed")
        }
    }
    
    func testGetUserFailure() async throws {
        mockAPIClient.setError(for: GetUserRequest.self, error: .notFound)
        
        let result = try await userService.getUser(cognitoId: "nonexistent")
        
        switch result {
        case .success:
            XCTFail("Get user should fail")
        case .failure(let error):
            XCTAssertEqual(error, .notFound)
        }
    }
}

// MARK: - CoordinateService Tests

final class CoordinateServiceTests: XCTestCase {
    private var coordinateService: CoordinateService!
    private var mockAPIClient: MockAPIClient!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        coordinateService = CoordinateService(apiClient: mockAPIClient)
    }
    
    override func tearDownWithError() throws {
        coordinateService = nil
        mockAPIClient = nil
    }
    
    func testGetCoordinatesSuccess() async throws {
        let result = try await coordinateService.getCoordinates(userId: "user123", page: 0)
        
        switch result {
        case .success(let coordinates):
            XCTAssertEqual(coordinates.count, 1)
            XCTAssertEqual(coordinates.first?.id, "coord123")
        case .failure:
            XCTFail("Get coordinates should succeed")
        }
    }
    
    func testCreateCoordinateSuccess() async throws {
        let request = CoordinateRequest(user_id: "user123")
        
        let result = try await coordinateService.createCoordinate(request)
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.id, "coord123")
            XCTAssertEqual(response.date, "2025-07-04")
        case .failure:
            XCTFail("Create coordinate should succeed")
        }
    }
    
    func testGetCoordinateItemsSuccess() async throws {
        let result = try await coordinateService.getCoordinateItems(coordinateId: "coord123")
        
        switch result {
        case .success(let items):
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items.first?.item_type, "top")
        case .failure:
            XCTFail("Get coordinate items should succeed")
        }
    }
}

// MARK: - FashionReviewService Tests

final class FashionReviewServiceTests: XCTestCase {
    private var fashionReviewService: FashionReviewService!
    private var mockAPIClient: MockAPIClient!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        fashionReviewService = FashionReviewService(apiClient: mockAPIClient)
    }
    
    override func tearDownWithError() throws {
        fashionReviewService = nil
        mockAPIClient = nil
    }
    
    func testSubmitFashionReviewSuccess() async throws {
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        let result = try await fashionReviewService.submitFashionReview(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        
        switch result {
        case .success(let response):
            XCTAssertEqual(response.current_coordinate.id, "coord123")
            XCTAssertEqual(response.ai_comment, "素敵なコーディネートですね！")
        case .failure:
            XCTFail("Submit fashion review should succeed")
        }
    }
    
    func testSubmitFashionReviewFailure() async throws {
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        mockAPIClient.setError(for: SubmitFashionReviewRequest.self, error: .unprocessableEntity)
        
        let result = try await fashionReviewService.submitFashionReview(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        
        switch result {
        case .success:
            XCTFail("Submit fashion review should fail")
        case .failure(let error):
            XCTAssertEqual(error, .unprocessableEntity)
        }
    }
}

// MARK: - Mock Services Tests

final class MockServicesTests: XCTestCase {
    
    func testMockUserService() async throws {
        let mockUserService = MockUserService()
        
        let result = try await mockUserService.getAllUsers()
        
        switch result {
        case .success(let users):
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users.first?.name, "Test User")
        case .failure:
            XCTFail("Mock user service should succeed")
        }
    }
    
    func testMockUserServiceWithCustomResponse() async throws {
        let mockUserService = MockUserService()
        let customUsers = UserInfo.mockDataList(count: 5)
        
        mockUserService.setSuccessResponse(for: .getAllUsers, data: customUsers)
        
        let result = try await mockUserService.getAllUsers()
        
        switch result {
        case .success(let users):
            XCTAssertEqual(users.count, 5)
            XCTAssertEqual(users.first?.name, "Test User 1")
        case .failure:
            XCTFail("Mock user service should succeed")
        }
    }
    
    func testMockCoordinateService() async throws {
        let mockCoordinateService = MockCoordinateService()
        
        let result = try await mockCoordinateService.getCoordinates(userId: "user123", page: 0)
        
        switch result {
        case .success(let coordinates):
            XCTAssertEqual(coordinates.count, 1)
            XCTAssertEqual(coordinates.first?.id, "coord123")
        case .failure:
            XCTFail("Mock coordinate service should succeed")
        }
    }
    
    func testMockCoordinateServiceWithEmptyList() async throws {
        let mockCoordinateService = MockCoordinateService()
        mockCoordinateService.setEmptyCoordinateList()
        
        let result = try await mockCoordinateService.getCoordinates(userId: "user123", page: 0)
        
        switch result {
        case .success(let coordinates):
            XCTAssertEqual(coordinates.count, 0)
        case .failure:
            XCTFail("Mock coordinate service should succeed")
        }
    }
    
    func testMockFashionReviewService() async throws {
        let mockFashionReviewService = MockFashionReviewService()
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        let result = try await mockFashionReviewService.submitFashionReview(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        
        switch result {
        case .success(let response):
            XCTAssertTrue(response.ai_comment.contains("素敵なコーディネート"))
        case .failure:
            XCTFail("Mock fashion review service should succeed")
        }
    }
    
}