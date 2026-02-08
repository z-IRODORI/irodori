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
    var homeResponse: HomeResponse = .init(recent_coordinates: [], analysis_summary: "", tags: nil)
    var coordinatesByDate: [Int: CoordinateRecommend] = [:]
    var loadingDateIDs: Set<Int> = []

    let apiClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol

    init(
        apiClient: HomeClientProtocol = MockHomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = CoordinateRecommendClient()//MockCoordinateRecommendClient()
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

    func addCoordinate(for dateID: Int) async {
        loadingDateIDs.insert(dateID)
        defer { loadingDateIDs.remove(dateID) }

        do {
            let result = try await coordinateRecommendClient.post(
                gender: "men",
                inputType: "アウター",
                category: "ジーンズジャケット",
                text: "ダメージジーンズのジャケット",
                numOutfits: 3,
                numCandidates: 5
            )

            switch result {
            case .success(let response):
                // APIから複数のコーディネートが返ってくるが、最初の1つを使用
                if let firstCoordinate = response.recommend_coordinates.first {
                    self.coordinatesByDate[dateID] = firstCoordinate
                }
            case .failure:
                // エラーハンドリング
                break
            }
        } catch {
            // エラーハンドリング
        }
    }

    func isLoading(for dateID: Int) -> Bool {
        return loadingDateIDs.contains(dateID)
    }

    func coordinate(for dateID: Int) -> CoordinateRecommend? {
        return coordinatesByDate[dateID]
    }
}
