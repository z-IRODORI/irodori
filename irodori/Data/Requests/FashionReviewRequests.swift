//
//  FashionReviewRequests.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import UIKit

// MARK: - Fashion Review Request

struct SubmitFashionReviewRequest: MultipartRequestProtocol {
    typealias Response = APIFashionReviewResponse
    
    let path: String = "/api/fashion_review"
    let method: HTTPMethod = .POST
    let formData: [String: Any]
    let fileData: Data?
    let fileName: String? = "image.jpg"
    let fieldName: String = "file"
    
    init(userId: String, userToken: String, image: UIImage, days: Int = 7) {
        self.formData = [
            "user_id": userId,
            "user_token": userToken,
            "days": days
        ]
        self.fileData = image.jpegData(compressionQuality: 0.8)
    }
}