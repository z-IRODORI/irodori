//
//  HomeViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct SelectCoordinateItem {
    let gender: String
    let input_type: String
    let category: String
    let text: String
    let image_url: String?
}

@MainActor
@Observable
final class HomeViewModel {
    var homeResponse: HomeResponse = .init(recent_coordinates: [], analysis_summary: "", tags: nil)
    var coordinatesByDate: [Int: [CoordinateRecommend]] = [:]
    var loadingDateIDs: Set<Int> = []
    var recentCoordinateAnalysis: String = ""
    var selectCoordinateItem: SelectCoordinateItem?

    let apiClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol
    let analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol

    init(
        apiClient: HomeClientProtocol = MockHomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = CoordinateRecommendClient(),//MockCoordinateRecommendClient()
        analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol = AnalyzeRecentCoordinateClient()
    ) {
        self.apiClient = apiClient
        self.coordinateRecommendClient = coordinateRecommendClient
        self.analyzeRecentCoordinateClient = analyzeRecentCoordinateClient
    }

    func onAppear() async {
        do {
            let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
            let result = try await apiClient.get(uid: uid)

            switch result {
            case .success(let response):
                self.homeResponse = response
                // home API のレスポンス後に analyze-recent-coordinate API を呼び出し
                await fetchRecentCoordinateAnalysis(uid: uid)
            case .failure:
                // エラーハンドリング
                break
            }
        } catch {
            // エラーハンドリング
        }
    }

    private func fetchRecentCoordinateAnalysis(uid: String) async {
        do {
            let result = try await analyzeRecentCoordinateClient.post(uid: uid, targetDays: 7)

            switch result {
            case .success(let response):
                self.recentCoordinateAnalysis = response.analyze_recent_coordinate
            case .failure:
                // エラー時はデフォルトメッセージを表示
                self.recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
            }
        } catch {
            // エラー時はデフォルトメッセージを表示
            self.recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
        }
    }

    func addCoordinateRandom(for dateID: Int) async {
        guard let item = selectCoordinateItem else { return }
        loadingDateIDs.insert(dateID)
        defer { loadingDateIDs.remove(dateID) }

        do {
            let result = try await coordinateRecommendClient.post(
                gender: item.gender,
                inputType: item.input_type,
                category: item.category,
                text: item.text,
                numOutfits: 10,
                numCandidates: 5
            )

            switch result {
            case .success(let response):
                // APIから複数のコーディネートを全て保存
                self.coordinatesByDate[dateID] = response.recommend_coordinates
            case .failure:
                // エラーハンドリング
                break
            }
        } catch {
            // エラーハンドリング
        }
    }

    func addCoordinateByItem(for dateID: Int) async {
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
                // APIから複数のコーディネートを全て保存
                self.coordinatesByDate[dateID] = response.recommend_coordinates
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

    func coordinates(for dateID: Int) -> [CoordinateRecommend] {
        return coordinatesByDate[dateID] ?? []
    }

    func setCoordinateItem(gender: String, input_type: String, category: String, text: String, image_url: String? = nil) {
        selectCoordinateItem = .init(gender: gender, input_type: input_type, category: category, text: text, image_url: image_url)
    }
}
