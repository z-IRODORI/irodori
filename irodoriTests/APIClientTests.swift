//
//  APIClientTests.swift
//  irodoriTests
//
//  Created by Claude on 2025/07/04.
//

import XCTest
import Combine
@testable import irodori

class APIClientTests: XCTestCase {
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        mockAPIClient = nil
        cancellables = nil
    }
    
    // MARK: - APIClient Tests
    
    func testAPIClientRequestSuccess() throws {
        let expectation = XCTestExpectation(description: "API request succeeds")
        
        let endpoint = APIEndpoint(path: "/test", method: .GET)
        
        mockAPIClient.request(endpoint, responseType: [UserInfo].self)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Request should succeed")
                    }
                },
                receiveValue: { users in
                    XCTAssertEqual(users.count, 1)
                    XCTAssertEqual(users.first?.name, "Test User")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAPIClientRequestFailure() throws {
        let expectation = XCTestExpectation(description: "API request fails")
        mockAPIClient.shouldFail = true
        
        let endpoint = APIEndpoint(path: "/test", method: .GET)
        
        mockAPIClient.request(endpoint, responseType: [UserInfo].self)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, APIError.networkError)
                        expectation.fulfill()
                    } else {
                        XCTFail("Request should fail")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Request should fail")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - UserAPIClient Tests

class UserAPIClientTests: XCTestCase {
    var userAPIClient: UserAPIClient!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        userAPIClient = UserAPIClient(apiClient: mockAPIClient)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        userAPIClient = nil
        mockAPIClient = nil
        cancellables = nil
    }
    
    func testGetAllUsersSuccess() throws {
        let expectation = XCTestExpectation(description: "Get all users succeeds")
        
        userAPIClient.getAllUsers()
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Get all users should succeed")
                    }
                },
                receiveValue: { users in
                    XCTAssertEqual(users.count, 1)
                    XCTAssertEqual(users.first?.email, "test@example.com")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCreateUserSuccess() throws {
        let expectation = XCTestExpectation(description: "Create user succeeds")
        
        let request = UserRegistrationRequest(
            cognito_id: "test123",
            user_name: "Test User",
            email: "test@example.com",
            icon_url: "https://example.com/icon.jpg"
        )
        
        userAPIClient.createUser(request)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Create user should succeed")
                    }
                },
                receiveValue: { response in
                    XCTAssertEqual(response.status, "success")
                    XCTAssertEqual(response.user_name, "Test User")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetUserSuccess() throws {
        let expectation = XCTestExpectation(description: "Get user succeeds")
        
        userAPIClient.getUser(cognitoId: "test123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Get user should succeed")
                    }
                },
                receiveValue: { user in
                    XCTAssertEqual(user.cognito_id, "cognito123")
                    XCTAssertEqual(user.name, "Test User")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - CoordinateAPIClient Tests

class CoordinateAPIClientTests: XCTestCase {
    var coordinateAPIClient: CoordinateAPIClient!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        coordinateAPIClient = CoordinateAPIClient(apiClient: mockAPIClient)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        coordinateAPIClient = nil
        mockAPIClient = nil
        cancellables = nil
    }
    
    func testGetCoordinatesSuccess() throws {
        let expectation = XCTestExpectation(description: "Get coordinates succeeds")
        
        coordinateAPIClient.getCoordinates(userId: "user123", page: 0)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Get coordinates should succeed")
                    }
                },
                receiveValue: { coordinates in
                    XCTAssertEqual(coordinates.count, 1)
                    XCTAssertEqual(coordinates.first?.id, "coord123")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCreateCoordinateSuccess() throws {
        let expectation = XCTestExpectation(description: "Create coordinate succeeds")
        
        let request = CoordinateRequest(user_id: "user123")
        
        coordinateAPIClient.createCoordinate(request)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Create coordinate should succeed")
                    }
                },
                receiveValue: { response in
                    XCTAssertEqual(response.id, "coord123")
                    XCTAssertEqual(response.date, "2025-07-04")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetCoordinateItemsSuccess() throws {
        let expectation = XCTestExpectation(description: "Get coordinate items succeeds")
        
        coordinateAPIClient.getCoordinateItems(coordinateId: "coord123")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Get coordinate items should succeed")
                    }
                },
                receiveValue: { items in
                    XCTAssertEqual(items.count, 1)
                    XCTAssertEqual(items.first?.item_type, "top")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - FashionReviewAPIClient Tests

class FashionReviewAPIClientTests: XCTestCase {
    var fashionReviewAPIClient: FashionReviewAPIClient!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockAPIClient = MockAPIClient()
        fashionReviewAPIClient = FashionReviewAPIClient(apiClient: mockAPIClient)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        fashionReviewAPIClient = nil
        mockAPIClient = nil
        cancellables = nil
    }
    
    func testSubmitFashionReviewSuccess() throws {
        let expectation = XCTestExpectation(description: "Submit fashion review succeeds")
        
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        fashionReviewAPIClient.submitFashionReview(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Submit fashion review should succeed")
                }
            },
            receiveValue: { response in
                XCTAssertEqual(response.current_coordinate.id, "coord123")
                XCTAssertEqual(response.ai_comment, "素敵なコーディネートですね！")
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Mock APIClient Tests

class MockAPIClientTests: XCTestCase {
    var mockUserAPIClient: MockUserAPIClient!
    var mockCoordinateAPIClient: MockCoordinateAPIClient!
    var mockFashionReviewAPIClient: MockFashionReviewAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockUserAPIClient = MockUserAPIClient()
        mockCoordinateAPIClient = MockCoordinateAPIClient()
        mockFashionReviewAPIClient = MockFashionReviewAPIClient()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        mockUserAPIClient = nil
        mockCoordinateAPIClient = nil
        mockFashionReviewAPIClient = nil
        cancellables = nil
    }
    
    func testMockUserAPIClientFailure() throws {
        let expectation = XCTestExpectation(description: "Mock user API client fails")
        mockUserAPIClient.shouldFail = true
        
        mockUserAPIClient.getAllUsers()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, APIError.networkError)
                        expectation.fulfill()
                    } else {
                        XCTFail("Request should fail")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Request should fail")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMockCoordinateAPIClientFailure() throws {
        let expectation = XCTestExpectation(description: "Mock coordinate API client fails")
        mockCoordinateAPIClient.shouldFail = true
        
        mockCoordinateAPIClient.getCoordinates(userId: "user123", page: 0)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, APIError.networkError)
                        expectation.fulfill()
                    } else {
                        XCTFail("Request should fail")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Request should fail")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMockFashionReviewAPIClientFailure() throws {
        let expectation = XCTestExpectation(description: "Mock fashion review API client fails")
        mockFashionReviewAPIClient.shouldFail = true
        
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        
        mockFashionReviewAPIClient.submitFashionReview(
            userId: "user123",
            userToken: "token123",
            image: testImage,
            days: 7
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTAssertEqual(error, APIError.networkError)
                    expectation.fulfill()
                } else {
                    XCTFail("Request should fail")
                }
            },
            receiveValue: { _ in
                XCTFail("Request should fail")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}