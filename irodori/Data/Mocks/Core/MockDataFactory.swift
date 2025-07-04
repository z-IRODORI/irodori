//
//  MockDataFactory.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

struct MockDataFactory {
    static func createMockResponse<T>(for type: T.Type) -> T {
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