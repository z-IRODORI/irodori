//
//  GPTClient.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/25.
//

import Foundation
import UIKit

final class GPTClient {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func postImageToGPT(image: UIImage, outingPurposeType: OutingPurposeType) async throws -> Result<CoordinateReview, HTTPError> {
        let request = CoordinateReviewRequest(image: image, outingPurposeType: outingPurposeType)
        return try await apiClient.request(request)
    }
}

// MARK: - Coordinate Review Request

struct CoordinateReviewRequest: JSONRequestProtocol {
    typealias Response = CoordinateReview
    
    let path: String = "/coordinate-review"
    let method: HTTPMethod = .post
    let requestBody: RequestBody?
    
    struct RequestBody: Codable {
        let imageBase64: String
        let outingPurposeId: Int
    }
    
    init(image: UIImage, outingPurposeType: OutingPurposeType) {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            self.requestBody = nil
            return
        }
        
        let base64String = jpegData.base64EncodedString()
        self.requestBody = RequestBody(
            imageBase64: base64String,
            outingPurposeId: outingPurposeType.number
        )
    }
}

