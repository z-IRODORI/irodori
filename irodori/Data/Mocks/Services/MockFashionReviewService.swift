//
//  MockFashionReviewService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import UIKit

final class MockFashionReviewService: FashionReviewServiceProtocol {
    private let mockAPIClient: MockAPIClient
    
    init(mockAPIClient: MockAPIClient = MockAPIClient()) {
        self.mockAPIClient = mockAPIClient
    }
    
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int) async throws -> Result<APIFashionReviewResponse, HTTPError> {
        let request = SubmitFashionReviewRequest(
            userId: userId,
            userToken: userToken,
            image: image,
            days: days
        )
        return try await mockAPIClient.request(request)
    }
}

// MARK: - Convenience Methods for Testing

extension MockFashionReviewService {
    func setSuccessResponse(_ response: APIFashionReviewResponse) {
        mockAPIClient.setResponse(for: SubmitFashionReviewRequest.self, response: response)
    }
    
    func setErrorResponse(_ error: HTTPError) {
        mockAPIClient.setError(for: SubmitFashionReviewRequest.self, error: error)
    }
    
    func setPositiveReview() {
        setSuccessResponse(APIFashionReviewResponse.mockPositiveReview())
    }
    
    func setConstructiveReview() {
        setSuccessResponse(APIFashionReviewResponse.mockConstructiveReview())
    }
    
    func setCustomReview(comment: String) {
        setSuccessResponse(APIFashionReviewResponse.mockDataWithCustomComment(comment))
    }
    
    func setDelay(_ delay: TimeInterval) {
        mockAPIClient.setDelay(delay)
    }
}