//
//  MockAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

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
        let mockResponse = MockDataFactory.createMockResponse(for: R.Response.self)
        return .success(mockResponse)
    }
}