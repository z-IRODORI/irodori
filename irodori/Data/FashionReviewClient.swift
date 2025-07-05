//
//  FashionReviewClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import UIKit

final class FashionReviewClient {
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func post(uid: String, image: UIImage, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError> {
        let request = FashionReviewRequest(image: image, userToken: uid, outingPurposeId: purposeNum)
        return try await apiClient.request(request)
    }
}

// MARK: - Fashion Review Request

struct FashionReviewRequest: MultipartRequestProtocol {
    typealias Response = FashionReviewResponse
    
    let path: String = "/v1/fashion-review"
    let method: HTTPMethod = .post
    let formData: [String: Any]
    let fileData: Data?
    let fileName: String? = "image.jpg"
    let fieldName: String = "image"
    
    init(image: UIImage, userToken: String, outingPurposeId: Int?) {
        self.formData = [
            "user_token": userToken,
            "outing_purpose_id": outingPurposeId as Any
        ]
        self.fileData = image.jpegData(compressionQuality: 0.8)
    }
}
