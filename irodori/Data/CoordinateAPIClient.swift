//
//  CoordinateAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import Combine

// MARK: - CoordinateAPIClient Protocol

protocol CoordinateAPIClientProtocol {
    func getCoordinates(userId: String, page: Int) -> AnyPublisher<[DailyCoordinate], APIError>
    func createCoordinate(_ request: CoordinateRequest) -> AnyPublisher<CoordinateResponse, APIError>
    func getCoordinateItems(coordinateId: String) -> AnyPublisher<[APICoordinateItem], APIError>
}

// MARK: - CoordinateAPIClient Implementation

class CoordinateAPIClient: CoordinateAPIClientProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func getCoordinates(userId: String, page: Int = 0) -> AnyPublisher<[DailyCoordinate], APIError> {
        let endpoint = APIEndpoint(
            path: "/api/coordinate/list/\(userId)?page=\(page)",
            method: .GET
        )
        
        return apiClient.request(endpoint, responseType: [DailyCoordinate].self)
    }
    
    func createCoordinate(_ request: CoordinateRequest) -> AnyPublisher<CoordinateResponse, APIError> {
        let endpoint = APIEndpoint(
            path: "/api/coordinate",
            method: .POST,
            body: [
                "user_id": request.user_id
            ]
        )
        
        return apiClient.request(endpoint, responseType: CoordinateResponse.self)
    }
    
    func getCoordinateItems(coordinateId: String) -> AnyPublisher<[APICoordinateItem], APIError> {
        let endpoint = APIEndpoint(
            path: "/api/coordinate-item/\(coordinateId)",
            method: .GET
        )
        
        return apiClient.request(endpoint, responseType: [APICoordinateItem].self)
    }
}