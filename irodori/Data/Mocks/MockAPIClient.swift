//
//  MockAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import UIKit

final class MockAPIClient: APIClientProtocol {
    private var responses: [String: Any] = [:]
    private var errors: [String: HTTPError] = [:]
    private var delay: TimeInterval = 0.1
    
    func setResponse<T: Codable>(for requestType: T.Type, response: Any) {
        let key = String(describing: requestType)
        responses[key] = response
    }
    
    func setError<T: Codable>(for requestType: T.Type, error: HTTPError) {
        let key = String(describing: requestType)
        errors[key] = error
    }
    
    func setDelay(_ delay: TimeInterval) {
        self.delay = delay
    }
    
    func request<R: APIRequestProtocol>(
        _ apiRequest: R
    ) async throws -> Result<R.Response, HTTPError> {
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        let key = String(describing: type(of: apiRequest))
        
        // Check if error is set for this request type
        if let error = errors[key] {
            return .failure(error)
        }
        
        // Check if response is set for this request type
        if let response = responses[key] as? R.Response {
            return .success(response)
        }
        
        // Return default mock data based on response type
        let mockResponse = createMockResponse(for: R.Response.self)
        return .success(mockResponse)
    }
    
    private func createMockResponse<T>(for type: T.Type) -> T {
        switch type {
        case is [UserInfo].Type:
            return [UserInfo.mockData()] as! T
        case is UserInfo.Type:
            return UserInfo.mockData() as! T
        case is UserRegistrationResponse.Type:
            return UserRegistrationResponse.mockData() as! T
        case is [DailyCoordinate].Type:
            return [DailyCoordinate.mockData()] as! T
        case is CoordinateResponse.Type:
            return CoordinateResponse.mockData() as! T
        case is [APICoordinateItem].Type:
            return [APICoordinateItem.mockData()] as! T
        case is APIFashionReviewResponse.Type:
            return APIFashionReviewResponse.mockData() as! T
        default:
            fatalError("Mock data not implemented for type: \(type)")
        }
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