//
//  HomeViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var homeResponse: HomeResponse = .init(recent_coordinates: [], analysis_summary: "", tags: nil)
    var coordinatesByDate: [Int: [CoordinateRecommend]] = [:]
    var loadingDateIDs: Set<Int> = []
    var recentCoordinateAnalysis: String = ""
    var selectCoordinateItemsByDate: [Int: SelectCoordinateItem] = [:]

    // ローディング状態
    var isLoadingHome: Bool = true
    var isLoadingAnalysis: Bool = true

    // クローゼットアイテムピッカー
    var closetItems: [ClosetItem] = []
    var isLoadingCloset = false
    var showingItemPicker = false
    private var pickerTargetDateID: Int? = nil

    // 編集モード関連
    var isEditMode: Bool = false
    var showDeleteConfirmation: Bool = false
    var coordinateToDelete: String? = nil
    var errorMessage: String? = nil
    var isDeletingCoordinate: Bool = false

    let apiClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol
    let analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol
    let closetClient: ClosetClientProtocol
    let deleteCoordinateClient: DeleteCoordinateClientProtocol
    private let plannerCacheRepository: HomePlannerCacheRepositoryProtocol

    init(
        apiClient: HomeClientProtocol = MockHomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = CoordinateRecommendClient(),//MockCoordinateRecommendClient()
        analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol = AnalyzeRecentCoordinateClient(),
        closetClient: ClosetClientProtocol = ClosetClient(),
        deleteCoordinateClient: DeleteCoordinateClientProtocol = DeleteCoordinateClient(),
        plannerCacheRepository: HomePlannerCacheRepositoryProtocol = HomePlannerCacheRepository()
    ) {
        self.apiClient = apiClient
        self.coordinateRecommendClient = coordinateRecommendClient
        self.analyzeRecentCoordinateClient = analyzeRecentCoordinateClient
        self.closetClient = closetClient
        self.deleteCoordinateClient = deleteCoordinateClient
        self.plannerCacheRepository = plannerCacheRepository
        loadPlannerCache()
    }

    func onAppear() async {
        isLoadingHome = true
        defer { isLoadingHome = false }

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
        isLoadingAnalysis = true
        defer { isLoadingAnalysis = false }

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

    func selectCoordinateItem(for dateID: Int) -> SelectCoordinateItem? {
        return selectCoordinateItemsByDate[dateID]
    }

    func addCoordinateRandom(for dateID: Int) async {
        guard let item = selectCoordinateItemsByDate[dateID] else { return }
        coordinatesByDate.removeValue(forKey: dateID)
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
                savePlannerCache(for: dateID)
            case .failure:
                // エラーハンドリング
                break
            }
        } catch {
            // エラーハンドリング
        }
    }

    func addCoordinateByItem(for dateID: Int) async {
        let recentCoordinates = homeResponse.recent_coordinates
        guard !recentCoordinates.isEmpty else { return }

        coordinatesByDate.removeValue(forKey: dateID)
        loadingDateIDs.insert(dateID)

        // ランダム選択の演出のための待機
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5秒

        loadingDateIDs.remove(dateID)

        if let finalCoord = recentCoordinates.randomElement() {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                coordinatesByDate[dateID] = [CoordinateRecommend(fromRecent: finalCoord)]
            }
            savePlannerCache(for: dateID)
        }
    }

    func resetCoordinate(for dateID: Int) {
        coordinatesByDate.removeValue(forKey: dateID)
        selectCoordinateItemsByDate.removeValue(forKey: dateID)
        savePlannerCache(for: dateID)
    }

    func isLoading(for dateID: Int) -> Bool {
        return loadingDateIDs.contains(dateID)
    }

    func coordinates(for dateID: Int) -> [CoordinateRecommend] {
        return coordinatesByDate[dateID] ?? []
    }

    // MARK: - Planner Cache

    private func loadPlannerCache() {
        for dateID in 0..<3 {
            let dateString = HomePlannerCacheRepository.dateString(for: dateID)
            guard let cache = plannerCacheRepository.load(dateString: dateString) else { continue }
            if !cache.coordinates.isEmpty {
                coordinatesByDate[dateID] = cache.coordinates
            }
            if let item = cache.selectedItem {
                selectCoordinateItemsByDate[dateID] = item
            }
        }
    }

    private func savePlannerCache(for dateID: Int) {
        let dateString = HomePlannerCacheRepository.dateString(for: dateID)
        let cache = PlannerDayCache(
            dateString: dateString,
            coordinates: coordinatesByDate[dateID] ?? [],
            selectedItem: selectCoordinateItemsByDate[dateID]
        )
        plannerCacheRepository.save(cache)
    }

    // MARK: - Closet Item Picker

    func showItemPicker(for dateID: Int) {
        pickerTargetDateID = dateID
        showingItemPicker = true
        Task {
            await fetchClosetItems()
        }
    }

    private func fetchClosetItems() async {
        isLoadingCloset = true
        defer { isLoadingCloset = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        do {
            let result = try await closetClient.get(uid: uid, itemType: nil)
            switch result {
            case .success(let response):
                self.closetItems = response.items.filter {
                    $0.item_type == "トップス" || $0.item_type == "ボトムス"
                }
            case .failure:
                break
            }
        } catch {}
    }

    func selectAndRecommend(closetItem: ClosetItem) async {
        guard let dateID = pickerTargetDateID else { return }
        selectCoordinateItemsByDate[dateID] = SelectCoordinateItem(
            gender: selectCoordinateItemsByDate[dateID]?.gender ?? "men",
            input_type: closetItem.item_type,
            category: closetItem.category ?? closetItem.item_type,
            text: [closetItem.color, closetItem.category].compactMap { $0 }.joined(separator: ", "),
            image_url: closetItem.image_url
        )
        await addCoordinateRandom(for: dateID)
    }

    // MARK: - Delete Coordinate

    func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditMode.toggle()
            if !isEditMode {
                // 編集モード終了時、選択状態をクリア
                coordinateToDelete = nil
                showDeleteConfirmation = false
            }
        }
    }

    func requestDelete(coordinateId: String) {
        coordinateToDelete = coordinateId
        showDeleteConfirmation = true
    }

    func deleteCoordinate() async {
        guard let coordinateId = coordinateToDelete else { return }

        isDeletingCoordinate = true
        defer { isDeletingCoordinate = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""

        do {
            let result = try await deleteCoordinateClient.delete(uid: uid, coordinateId: coordinateId)

            switch result {
            case .success(let response):
                if response.success {
                    // 成功時、UIから削除
                    withAnimation(.easeInOut(duration: 0.3)) {
                        homeResponse.recent_coordinates.removeAll { $0.id == coordinateId }
                    }
                    showDeleteConfirmation = false
                    coordinateToDelete = nil
                    // 削除後、編集モードも終了
                    isEditMode = false
                } else {
                    errorMessage = response.message
                }
            case .failure(let error):
                errorMessage = error.errorDescription
            }
        } catch {
            errorMessage = "削除に失敗しました"
        }
    }
}
