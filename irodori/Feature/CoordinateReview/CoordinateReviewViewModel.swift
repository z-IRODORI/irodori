//
//  CoordinateReviewViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/16.
//

import UIKit

@MainActor
@Observable
final class CoordinateReviewViewModel {
    let coordinateImage: UIImage
    let apiClient: FashionReviewClientProtocol
    init(coordinateImage: UIImage, apiClient: FashionReviewClientProtocol) {
        self.coordinateImage = coordinateImage
        self.apiClient = apiClient
    }

    var fashionReview: FashionReviewResponse?
    var isFinishedRequest = false

    func loadingOnAppear() async {
        do {
            let fashionReviewResponse: Result<FashionReviewResponse, Error> = try await apiClient.post(
                uid: UUID().uuidString,
                image: coordinateImage.correctOrientation,
                purposeNum: nil//tag.number
            )

            switch fashionReviewResponse {
            case .success(let fashionReview):
                self.fashionReview = fashionReview
                isFinishedRequest = true
            case .failure(let error):
                print("Error: \(error)")
                return
            }
        } catch {
            // TODO: - エラー処理
        }
    }
}
