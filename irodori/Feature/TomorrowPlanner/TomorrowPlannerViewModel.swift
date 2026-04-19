//
//  TomorrowPlannerViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/19.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TomorrowPlannerViewModel {
    enum DisplayMode {
        case card
        case grid
    }

    // 明日 = dateID 1（HomePlannerCacheRepository と共通）
    private let tomorrowDateID = 1

    var coordinates: [CoordinateRecommend] = []
    var isLoading = false
    var selectCoordinateItem: SelectCoordinateItem?
    var displayMode: DisplayMode = .card
    var selectedCoordinateIndex: Int = 0

    // クローゼットアイテムピッカー
    var closetItems: [ClosetItem] = []
    var isLoadingCloset = false
    var showingItemPicker = false

    private var recentCoordinates: [RecentCoordinate] = []

    let homeClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol
    let closetClient: ClosetClientProtocol
    private let plannerCacheRepository: HomePlannerCacheRepositoryProtocol

    init(
        homeClient: HomeClientProtocol = HomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = CoordinateRecommendClient(),
        closetClient: ClosetClientProtocol = ClosetClient(),
        plannerCacheRepository: HomePlannerCacheRepositoryProtocol = HomePlannerCacheRepository()
    ) {
        self.homeClient = homeClient
        self.coordinateRecommendClient = coordinateRecommendClient
        self.closetClient = closetClient
        self.plannerCacheRepository = plannerCacheRepository
        loadCache()
    }

    func onAppear() async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        do {
            let result = try await homeClient.get(uid: uid)
            if case .success(let response) = result {
                recentCoordinates = response.recent_coordinates
            }
        } catch {}
    }

    // MARK: - コーディネート追加

    /// ランダム：直近コーデからランダム選択
    func addCoordinateRandom() async {
        guard !recentCoordinates.isEmpty else { return }
        coordinates = []
        isLoading = true

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        isLoading = false

        if let coord = recentCoordinates.randomElement() {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                coordinates = [CoordinateRecommend(fromRecent: coord)]
            }
            saveCache()
        }
    }

    /// アイテムから提案：選択アイテムをもとに API でコーデを取得
    func addCoordinateByItem() async {
        guard let item = selectCoordinateItem else { return }
        coordinates = []
        isLoading = true
        defer { isLoading = false }

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
                coordinates = response.recommend_coordinates
                saveCache()
            case .failure:
                break
            }
        } catch {}
    }

    // MARK: - リセット

    func reset() {
        coordinates = []
        selectCoordinateItem = nil
        displayMode = .card
        saveCache()
    }

    // MARK: - 表示モード切り替え

    func switchToCardMode(at index: Int) {
        displayMode = .card
        selectedCoordinateIndex = index
    }

    // MARK: - アイテムピッカー

    func showItemPicker() {
        showingItemPicker = true
        Task { await fetchClosetItems() }
    }

    private func fetchClosetItems() async {
        isLoadingCloset = true
        defer { isLoadingCloset = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        do {
            let result = try await closetClient.get(uid: uid, itemType: nil)
            if case .success(let response) = result {
                closetItems = response.items.filter {
                    $0.item_type == "トップス" || $0.item_type == "ボトムス"
                }
            }
        } catch {}
    }

    func selectAndRecommend(closetItem: ClosetItem) async {
        selectCoordinateItem = SelectCoordinateItem(
            gender: selectCoordinateItem?.gender ?? "men",
            input_type: closetItem.item_type,
            category: closetItem.category ?? closetItem.item_type,
            text: [closetItem.color, closetItem.category].compactMap { $0 }.joined(separator: ", "),
            image_url: closetItem.image_url
        )
        await addCoordinateByItem()
    }

    // MARK: - キャッシュ（HomePlannerCacheRepository の明日スロットを共有）

    private func loadCache() {
        let dateString = HomePlannerCacheRepository.dateString(for: tomorrowDateID)
        guard let cache = plannerCacheRepository.load(dateString: dateString) else { return }
        if !cache.coordinates.isEmpty {
            coordinates = cache.coordinates
        }
        selectCoordinateItem = cache.selectedItem
    }

    private func saveCache() {
        let dateString = HomePlannerCacheRepository.dateString(for: tomorrowDateID)
        let cache = PlannerDayCache(
            dateString: dateString,
            coordinates: coordinates,
            selectedItem: selectCoordinateItem
        )
        plannerCacheRepository.save(cache)
    }
}
