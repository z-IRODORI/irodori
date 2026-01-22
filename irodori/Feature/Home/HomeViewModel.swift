//
//  HomeViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

@MainActor
@Observable
final class HomeViewModel {
    var homeResponse: HomeResponse = .init(recent_coordinates: [], coordinate_analyze: "", tags: nil)
    var coordinateRecommendResponse: CoordinateRecommendResponse?
    var isLoadingCoordinateRecommend: Bool = false

    let apiClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol

    init(
        apiClient: HomeClientProtocol = MockHomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = MockCoordinateRecommendClient()
    ) {
        self.apiClient = apiClient
        self.coordinateRecommendClient = coordinateRecommendClient
    }

    func onAppear() async {
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
            let result = try await apiClient.get(uid: uid)

            switch result {
            case .success(let response):
                self.homeResponse = response
            case .failure:
                // エラーハンドリング
                break
            }
        } catch {
            // エラーハンドリング
        }
    }

    func addCoordinate() async {
        isLoadingCoordinateRecommend = true
        defer { isLoadingCoordinateRecommend = false }

        do {
            let result = try await coordinateRecommendClient.post(
                gender: "women",
                inputType: "トップス",
                category: "Tシャツ",
                text: "春",
                numOutfits: 3,
                numCandidates: 5
            )

            switch result {
            case .success(let response):
                self.coordinateRecommendResponse = response
                print("コーデ追加成功: \(response.recommend_coordinates.count)件")
            case .failure(let error):
                print("コーデ追加エラー: \(error)")
                // エラーハンドリング
            }
        } catch {
            print("コーデ追加例外: \(error)")
            // エラーハンドリング
        }
    }
}
