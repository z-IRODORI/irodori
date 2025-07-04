//
//  MockAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import Combine
import UIKit

// MARK: - MockAPIClient

class MockAPIClient: APIClientProtocol {
    var shouldFail: Bool = false
    var mockDelay: TimeInterval = 0.1
    
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) -> AnyPublisher<T, APIError> {
        return Future<T, APIError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + self.mockDelay) {
                if self.shouldFail {
                    promise(.failure(.networkError))
                    return
                }
                
                let mockData = self.createMockData(for: responseType, endpoint: endpoint)
                promise(.success(mockData))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data, responseType: T.Type) -> AnyPublisher<T, APIError> {
        return Future<T, APIError> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + self.mockDelay) {
                if self.shouldFail {
                    promise(.failure(.networkError))
                    return
                }
                
                let mockData = self.createMockData(for: responseType, endpoint: endpoint)
                promise(.success(mockData))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func createMockData<T: Codable>(for type: T.Type, endpoint: APIEndpoint) -> T {
        if type == [UserInfo].self {
            return [UserInfo.mockData()] as! T
        } else if type == UserInfo.self {
            return UserInfo.mockData() as! T
        } else if type == UserRegistrationResponse.self {
            return UserRegistrationResponse.mockData() as! T
        } else if type == [DailyCoordinate].self {
            return [DailyCoordinate.mockData()] as! T
        } else if type == CoordinateResponse.self {
            return CoordinateResponse.mockData() as! T
        } else if type == [APICoordinateItem].self {
            return [APICoordinateItem.mockData()] as! T
        } else if type == APIFashionReviewResponse.self {
            return APIFashionReviewResponse.mockData() as! T
        }
        
        fatalError("Mock data not implemented for type: \(type)")
    }
}

// MARK: - Mock Data Extensions

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
}

extension UserRegistrationResponse {
    static func mockData() -> UserRegistrationResponse {
        return UserRegistrationResponse(
            status: "success",
            id: "user123",
            user_name: "Test User"
        )
    }
}

extension DailyCoordinate {
    static func mockData() -> DailyCoordinate {
        return DailyCoordinate(
            date: "2025-07-04",
            id: "coord123",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
}

extension CoordinateResponse {
    static func mockData() -> CoordinateResponse {
        return CoordinateResponse(
            id: "coord123",
            date: "2025-07-04",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
}

extension APICoordinateItem {
    static func mockData() -> APICoordinateItem {
        return APICoordinateItem(
            id: "item123",
            coordinate_id: "coord123",
            item_type: "top",
            item_image_path: "https://example.com/item.jpg"
        )
    }
}

extension APIFashionReviewResponse {
    static func mockData() -> APIFashionReviewResponse {
        return APIFashionReviewResponse(
            current_coordinate: APICoordinateResponseDetail.mockData(),
            recent_coordinates: [APICoordinateResponseDetail.mockData()],
            items: [APICoordinateItem.mockData()],
            ai_comment: "素敵なコーディネートですね！"
        )
    }
}

extension APICoordinateResponseDetail {
    static func mockData() -> APICoordinateResponseDetail {
        return APICoordinateResponseDetail(
            id: "coord123",
            date: "2025-07-04",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
}

// MARK: - MockUserAPIClient

class MockUserAPIClient: UserAPIClientProtocol {
    var shouldFail: Bool = false
    
    func getAllUsers() -> AnyPublisher<[UserInfo], APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just([UserInfo.mockData()])
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func createUser(_ request: UserRegistrationRequest) -> AnyPublisher<UserRegistrationResponse, APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just(UserRegistrationResponse.mockData())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getUser(cognitoId: String) -> AnyPublisher<UserInfo, APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just(UserInfo.mockData())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - MockCoordinateAPIClient

class MockCoordinateAPIClient: CoordinateAPIClientProtocol {
    var shouldFail: Bool = false
    
    func getCoordinates(userId: String, page: Int) -> AnyPublisher<[DailyCoordinate], APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just([DailyCoordinate.mockData()])
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func createCoordinate(_ request: CoordinateRequest) -> AnyPublisher<CoordinateResponse, APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just(CoordinateResponse.mockData())
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    func getCoordinateItems(coordinateId: String) -> AnyPublisher<[APICoordinateItem], APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just([APICoordinateItem.mockData()])
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - MockFashionReviewAPIClient

class MockFashionReviewAPIClient: FashionReviewAPIClientProtocol {
    var shouldFail: Bool = false
    
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int) -> AnyPublisher<APIFashionReviewResponse, APIError> {
        if shouldFail {
            return Fail(error: APIError.networkError)
                .eraseToAnyPublisher()
        }
        
        return Just(APIFashionReviewResponse.mockData())
            .setFailureType(to: APIError.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}