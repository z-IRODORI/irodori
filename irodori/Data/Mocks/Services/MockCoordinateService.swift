//
//  MockCoordinateService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

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

// MARK: - Convenience Methods for Testing

extension MockCoordinateService {
    func setSuccessResponse(for method: CoordinateServiceMethod, data: Any) {
        switch method {
        case .getCoordinates:
            mockAPIClient.setResponse(for: GetCoordinatesRequest.self, response: data)
        case .createCoordinate:
            mockAPIClient.setResponse(for: CreateCoordinateRequest.self, response: data)
        case .getCoordinateItems:
            mockAPIClient.setResponse(for: GetCoordinateItemsRequest.self, response: data)
        }
    }
    
    func setErrorResponse(for method: CoordinateServiceMethod, error: HTTPError) {
        switch method {
        case .getCoordinates:
            mockAPIClient.setError(for: GetCoordinatesRequest.self, error: error)
        case .createCoordinate:
            mockAPIClient.setError(for: CreateCoordinateRequest.self, error: error)
        case .getCoordinateItems:
            mockAPIClient.setError(for: GetCoordinateItemsRequest.self, error: error)
        }
    }
    
    func setCustomCoordinateList(_ coordinates: [DailyCoordinate]) {
        setSuccessResponse(for: .getCoordinates, data: coordinates)
    }
    
    func setEmptyCoordinateList() {
        setSuccessResponse(for: .getCoordinates, data: [DailyCoordinate]())
    }
}

enum CoordinateServiceMethod {
    case getCoordinates
    case createCoordinate
    case getCoordinateItems
}