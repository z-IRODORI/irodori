//
//  RecommendCoordinateViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/06.
//

import Foundation

@MainActor
@Observable
final class RecommendCoordinateViewModel {

    let recommendCoordinateClient: RecommendCoordinateClientProtocol
    // おすすめコーディネート
    var recommendCoordinatesState: FetchState<RecommendCoordinateResponse> = .initial
    var selectedRecommendCoordinate: RecommendCoordinate = .init(
        id: 0,
        image_url: "",
        pin_url_guess: "",
        coordinate_review: nil,
        tops_categorize: nil,
        bottoms_categorize: nil,
        affiliate_tops: [],
        affiliate_bottoms: []
    )
    var isShowingWebView = false
    var webURLString = ""

    init(recommendCoordinateClient: RecommendCoordinateClientProtocol) {
        self.recommendCoordinateClient = recommendCoordinateClient
    }

    func onAppear() async {
        await fetchRecommendCoordinates()
    }

    func setSelectedRecommendCoordinate(coordinate: RecommendCoordinate) {
        selectedRecommendCoordinate = coordinate
    }

    func setWebViewURLString(url: String) {
        isShowingWebView = true
        webURLString = url
    }

    func tappedReloadButton() async {
        await fetchRecommendCoordinates()
    }

    private func fetchRecommendCoordinates() async {
        do {
            // 性別を取得（デフォルトは"other"）
            let gender = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue) ?? "men"

            recommendCoordinatesState = .loading
            let result = try await recommendCoordinateClient.post(gender: gender)

            switch result {
            case .success(let response):
                recommendCoordinatesState = .loaded(response)
                if let recommendCoordinate = response.coordinates.first {
                    selectedRecommendCoordinate = recommendCoordinate
                }
            case .failure(let httpError):
                recommendCoordinatesState = .failed(httpError)
            }
        } catch {
            recommendCoordinatesState = .failed(HTTPError.badRequest)
        }
    }
}
