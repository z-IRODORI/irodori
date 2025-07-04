//
//  CoordinateService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

protocol CoordinateServiceProtocol: Sendable {
    func getCoordinates(userId: String, page: Int) async throws -> Result<[DailyCoordinate], HTTPError>
    func createCoordinate(_ request: CoordinateRequest) async throws -> Result<CoordinateResponse, HTTPError>
    func getCoordinateItems(coordinateId: String) async throws -> Result<[APICoordinateItem], HTTPError>
}

final class CoordinateService: CoordinateServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func getCoordinates(userId: String, page: Int = 0) async throws -> Result<[DailyCoordinate], HTTPError> {
        let request = GetCoordinatesRequest(userId: userId, page: page)
        return try await apiClient.request(request)
    }
    
    func createCoordinate(_ request: CoordinateRequest) async throws -> Result<CoordinateResponse, HTTPError> {
        let apiRequest = CreateCoordinateRequest(coordinateRequest: request)
        return try await apiClient.request(apiRequest)
    }
    
    func getCoordinateItems(coordinateId: String) async throws -> Result<[APICoordinateItem], HTTPError> {
        let request = GetCoordinateItemsRequest(coordinateId: coordinateId)
        return try await apiClient.request(request)
    }
}