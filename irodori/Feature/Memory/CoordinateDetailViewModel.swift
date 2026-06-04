//
//  CoordinateDetailViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import UIKit

@Observable
@MainActor
final class CoordinateDetailViewModel {
    let coordinateId: String
    let coordinateImageURL: String
    let coordinateDetailClient: CoordinateDetailClientProtocol

    var coordinateDetail: CoordinateDetailResponse? = nil
    var isLoadingDetail = false
    var willShowRecommendCoordinateView = false
    var willShowChatView = false

    init(
        coordinateId: String,
        coordinateImageURL: String,
        coordinateDetailClient: CoordinateDetailClientProtocol
    ) {
        self.coordinateId = coordinateId
        self.coordinateImageURL = coordinateImageURL
        self.coordinateDetailClient = coordinateDetailClient
    }

    func onAppear() async {
        await fetchCoordinateDetail()
    }

    func fetchCoordinateDetail() async {
        isLoadingDetail = true
        defer { isLoadingDetail = false }

        do {
            let result = try await coordinateDetailClient.get(coordinateId: coordinateId)
            switch result {
            case .success(let response):
                coordinateDetail = response
            case .failure(let error):
                print("Failed to fetch coordinate detail: \(error)")
            }
        } catch {
            print("Error fetching coordinate detail: \(error)")
        }
    }

    func tappedRecommendCoordinateButton() {
        willShowRecommendCoordinateView.toggle()
    }

    func tappedWillShowChatView() {
        willShowChatView.toggle()
    }
}
