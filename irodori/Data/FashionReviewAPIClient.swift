//
//  FashionReviewAPIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import Combine
import UIKit

// MARK: - FashionReviewAPIClient Protocol

protocol FashionReviewAPIClientProtocol {
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int) -> AnyPublisher<APIFashionReviewResponse, APIError>
}

// MARK: - FashionReviewAPIClient Implementation

class FashionReviewAPIClient: FashionReviewAPIClientProtocol {
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }
    
    func submitFashionReview(userId: String, userToken: String, image: UIImage, days: Int = 7) -> AnyPublisher<APIFashionReviewResponse, APIError> {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: APIError.encodingError)
                .eraseToAnyPublisher()
        }
        
        let endpoint = APIEndpoint(
            path: "/api/fashion_review",
            method: .POST,
            body: [
                "user_id": userId,
                "user_token": userToken,
                "days": days,
                "file": "image.jpg" // This will be replaced with actual image data in upload method
            ]
        )
        
        return apiClient.upload(endpoint, data: imageData, responseType: APIFashionReviewResponse.self)
    }
}