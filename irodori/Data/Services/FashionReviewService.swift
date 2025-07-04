//
//  FashionReviewService.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import UIKit

protocol FashionReviewServiceProtocol: Sendable {
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int) async throws -> Result<APIFashionReviewResponse, HTTPError>
}

final class FashionReviewService: FashionReviewServiceProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int = 7) async throws -> Result<APIFashionReviewResponse, HTTPError> {
        let request = SubmitFashionReviewRequest(
            userId: userId,
            userToken: userToken,
            image: image,
            days: days
        )
        return try await apiClient.request(request)
    }
}