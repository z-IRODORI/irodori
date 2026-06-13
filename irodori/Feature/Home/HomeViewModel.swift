//
//  HomeViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation
import SwiftUI

/// WebView シートで開く URL のラッパー（.sheet(item:) 用に Identifiable）
struct HomeWebLink: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }
}

@MainActor
@Observable
final class HomeViewModel {
    var homeResponse: HomeResponse = .init(recent_coordinates: [], analysis_summary: "", tags: nil)
    var coordinatesByDate: [Int: [CoordinateRecommend]] = [:]
    var loadingDateIDs: Set<Int> = []
    var recentCoordinateAnalysis: String = ""
    var selectCoordinateItemsByDate: [Int: SelectCoordinateItem] = [:]

    // ローディング・エラー状態
    var isLoadingHome: Bool = true
    var isLoadingAnalysis: Bool = true
    var hasLoadError: Bool = false

    // クローゼットアイテムピッカー
    var closetItems: [ClosetItem] = []
    var isLoadingCloset = false
    var showingItemPicker = false
    private var pickerTargetDateID: Int? = nil

    // 編集モード関連
    var isEditMode: Bool = false
    var showDeleteConfirmation: Bool = false
    var coordinateToDelete: String? = nil
    var isDeletingCoordinate: Bool = false

    // 明日のコーデ推薦
    var dailyRecommendation: DailyRecommendationResponse? = nil
    var isLoadingDailyRecommendation: Bool = false
    var hasDailyRecommendationError: Bool = false
    var selectedDailyRecommendation: DailyRecommendationItem? = nil

    // コーデコラージュ (クローゼットでコーデ)
    var outfitCollage: OutfitCollageResponse? = nil
    var isLoadingOutfitCollage: Bool = false
    var hasOutfitCollageError: Bool = false
    var isRegeneratingOutfitCollage: Bool = false
    var showingOutfitCollageDetail: Bool = false

    // 買い足し提案（closet bridge）
    var closetBridge: ClosetBridgeResponse? = nil
    var isLoadingClosetBridge: Bool = false
    var hasClosetBridgeError: Bool = false
    /// タップした商品ページ / ZOZOTOWN検索ページ（WebView シートで開く用）
    var selectedWebLink: HomeWebLink? = nil

    // コーデに合うおすすめ商品（アフィリエイト。コーデ詳細で遅延ロード）
    var outfitRecommendations: ClosetBridgeResponse? = nil
    var isLoadingOutfitRecommendations: Bool = false
    var hasOutfitRecommendationsError: Bool = false

    // 居住地 (天気ヘッダの場所バッジ用. UserDefaults と同期)
    var currentPrefectureCode: String? = UserDefaults.standard.string(
        forKey: UserDefaultsKey.prefectureCode.rawValue
    )

    var currentPrefectureName: String {
        if let code = currentPrefectureCode, let p = Prefecture.find(byCode: code) {
            return p.name
        }
        return Prefecture.default.name
    }

    /// 居住地はコーデの再生成を伴うため JST カレンダー日で 1日1回まで.
    /// 未変更 (lastChanged が無い) は常に true (オンボーディング後の初変更も許容).
    var canChangePrefectureToday: Bool {
        guard let last = UserDefaults.standard.object(
            forKey: UserDefaultsKey.prefectureLastChangedAt.rawValue
        ) as? Date else { return true }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return !cal.isDate(last, inSameDayAs: Date())
    }

    let apiClient: HomeClientProtocol
    let coordinateRecommendClient: CoordinateRecommendClientProtocol
    let analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol
    let closetClient: ClosetClientProtocol
    let deleteCoordinateClient: DeleteCoordinateClientProtocol
    let dailyRecommendationClient: DailyRecommendationClientProtocol
    let closetBridgeClient: ClosetBridgeClientProtocol
    let updatePrefectureClient: UpdateUserPrefectureClientProtocol
    let outfitCollageClient: OutfitCollageClientProtocol
    private let plannerCacheRepository: HomePlannerCacheRepositoryProtocol

    init(
        apiClient: HomeClientProtocol = MockHomeClient(),
        coordinateRecommendClient: CoordinateRecommendClientProtocol = CoordinateRecommendClient(),//MockCoordinateRecommendClient()
        analyzeRecentCoordinateClient: AnalyzeRecentCoordinateClientProtocol = AnalyzeRecentCoordinateClient(),
        closetClient: ClosetClientProtocol = ClosetClient(),
        deleteCoordinateClient: DeleteCoordinateClientProtocol = DeleteCoordinateClient(),
        dailyRecommendationClient: DailyRecommendationClientProtocol = DailyRecommendationClient(),
        closetBridgeClient: ClosetBridgeClientProtocol = ClosetBridgeClient(),
        updatePrefectureClient: UpdateUserPrefectureClientProtocol = UpdateUserPrefectureClient(),
        outfitCollageClient: OutfitCollageClientProtocol = OutfitCollageClient(),
        plannerCacheRepository: HomePlannerCacheRepositoryProtocol = HomePlannerCacheRepository()
    ) {
        self.apiClient = apiClient
        self.coordinateRecommendClient = coordinateRecommendClient
        self.analyzeRecentCoordinateClient = analyzeRecentCoordinateClient
        self.closetClient = closetClient
        self.deleteCoordinateClient = deleteCoordinateClient
        self.dailyRecommendationClient = dailyRecommendationClient
        self.closetBridgeClient = closetBridgeClient
        self.updatePrefectureClient = updatePrefectureClient
        self.outfitCollageClient = outfitCollageClient
        self.plannerCacheRepository = plannerCacheRepository
        loadPlannerCache()
    }

    func onAppear() async {
        isLoadingHome = true
        isLoadingAnalysis = true
        isLoadingDailyRecommendation = true
        isLoadingOutfitCollage = true
        isLoadingClosetBridge = true
        hasLoadError = false
        hasDailyRecommendationError = false
        hasOutfitCollageError = false
        hasClosetBridgeError = false

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )

        // 5つのAPIを同時に起動
        async let homeResult = apiClient.get(uid: uid)
        async let analysisResult = analyzeRecentCoordinateClient.post(uid: uid, targetDays: 7)
        async let dailyResult = dailyRecommendationClient.get(uid: uid, gender: gender)
        async let collageResult = outfitCollageClient.get(uid: uid, gender: gender)
        async let closetBridgeResult = closetBridgeClient.get(uid: uid, gender: gender)

        // コーデ一覧: 完了次第スケルトンを解除して表示
        do {
            switch try await homeResult {
            case .success(let response):
                homeResponse = response
            case .failure:
                hasLoadError = true
            }
        } catch {
            hasLoadError = true
        }
        isLoadingHome = false

        // 分析: 完了次第「今週のあなたへ」を更新（homeより遅くなることが多い）
        do {
            switch try await analysisResult {
            case .success(let response):
                recentCoordinateAnalysis = response.analyze_recent_coordinate
            case .failure:
                recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
            }
        } catch {
            recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
        }
        isLoadingAnalysis = false

        // 明日のコーデ：完了次第表示（キャッシュHIT時は瞬時、フォールバック時は1-2秒）
        do {
            switch try await dailyResult {
            case .success(let response):
                dailyRecommendation = response
            case .failure:
                hasDailyRecommendationError = true
            }
        } catch {
            hasDailyRecommendationError = true
        }
        isLoadingDailyRecommendation = false

        // コーデコラージュ：完了次第表示（当日キャッシュHIT時は瞬時、初回生成は1秒前後）
        do {
            switch try await collageResult {
            case .success(let response):
                outfitCollage = response
            case .failure:
                hasOutfitCollageError = true
            }
        } catch {
            hasOutfitCollageError = true
        }
        isLoadingOutfitCollage = false

        // 買い足し提案：完了次第表示（Gemini×2 + Yahoo 検索のため数秒かかる場合がある）
        do {
            switch try await closetBridgeResult {
            case .success(let response):
                closetBridge = response
            case .failure:
                hasClosetBridgeError = true
            }
        } catch {
            hasClosetBridgeError = true
        }
        isLoadingClosetBridge = false
    }

    // MARK: - Outfit Collage (クローゼットでコーデ)

    /// コラージュのみ再取得 (エラー時の再試行用)
    func refreshOutfitCollage() async {
        isLoadingOutfitCollage = true
        hasOutfitCollageError = false

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await outfitCollageClient.get(uid: uid, gender: gender) {
            case .success(let response):
                outfitCollage = response
            case .failure:
                hasOutfitCollageError = true
            }
        } catch {
            hasOutfitCollageError = true
        }
        isLoadingOutfitCollage = false
    }

    /// シャッフル: 現在のアイテムを避けて再生成
    func shuffleOutfitCollage() async {
        guard let current = outfitCollage else { return }
        await regenerateOutfitCollage(
            itemIds: [:],
            excludeItemIds: current.items.map { $0.id }
        )
    }

    /// アイテム差し替え: 指定スロットだけ入れ替え、他のスロットはピン留めして再生成
    func swapOutfitCollageItem(slot: String, to item: OutfitCollageItem) async {
        guard let current = outfitCollage else { return }
        var itemIds: [String: String] = [:]
        for it in current.items {
            itemIds[it.slot] = it.id
        }
        itemIds[slot] = item.id
        await regenerateOutfitCollage(itemIds: itemIds, excludeItemIds: [])
    }

    private func regenerateOutfitCollage(itemIds: [String: String], excludeItemIds: [String], anchorItemId: String? = nil) async {
        guard !isRegeneratingOutfitCollage else { return }
        isRegeneratingOutfitCollage = true
        defer { isRegeneratingOutfitCollage = false }

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await outfitCollageClient.regenerate(
                uid: uid, gender: gender, itemIds: itemIds, excludeItemIds: excludeItemIds, anchorItemId: anchorItemId
            ) {
            case .success(let response):
                if response.isDisplayable {
                    outfitCollage = response
                } else {
                    ToastManager.shared.show("コーデを組み替えられませんでした")
                }
            case .failure:
                ToastManager.shared.show("コーデの再生成に失敗しました")
            }
        } catch {
            ToastManager.shared.show("コーデの再生成に失敗しました")
        }
    }

    /// 手持ちアイテムを起点にコーデを生成する (アイテム選択導線)。
    /// 起点アイテムは item_type からスロットを自動判定して固定される (API 側)。生成後におすすめも更新。
    func generateOutfitFromItem(_ closetItem: ClosetItem) async {
        await regenerateOutfitCollage(itemIds: [:], excludeItemIds: [], anchorItemId: closetItem.id)
        await loadOutfitRecommendations()
    }

    /// アイテム選択ピッカー用にクローゼットを読み込む (未取得時のみ)。
    func loadClosetItemsIfNeeded() async {
        if closetItems.isEmpty {
            await fetchClosetItems()
        }
    }

    /// コーデに合うおすすめ商品 (アフィリエイト) を遅延ロードする。
    /// コーデのアイテム (category, color) を closet-bridge に渡して取得。失敗/0件はセクション非表示。
    func loadOutfitRecommendations() async {
        guard let collage = outfitCollage, collage.isDisplayable, !collage.items.isEmpty else {
            outfitRecommendations = nil
            return
        }
        isLoadingOutfitRecommendations = true
        hasOutfitRecommendationsError = false

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        let items = collage.items
            .map { OutfitRecommendItem(category: $0.category ?? "", color: $0.color ?? "") }
            .filter { !$0.category.isEmpty }
        do {
            switch try await outfitCollageClient.recommendations(uid: uid, gender: gender, items: items) {
            case .success(let response):
                outfitRecommendations = response
            case .failure:
                hasOutfitRecommendationsError = true
            }
        } catch {
            hasOutfitRecommendationsError = true
        }
        isLoadingOutfitRecommendations = false
    }

    // MARK: - Closet Bridge (買い足し提案)

    /// 買い足し提案のみ再取得（再試行ボタン用）
    func refreshClosetBridge() async {
        isLoadingClosetBridge = true
        hasClosetBridgeError = false

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await closetBridgeClient.get(uid: uid, gender: gender) {
            case .success(let response):
                closetBridge = response
            case .failure:
                hasClosetBridgeError = true
            }
        } catch {
            hasClosetBridgeError = true
        }
        isLoadingClosetBridge = false
    }

    /// 場所バッジから居住地を変更. UD/サーバ永続化 + daily-recommendation 単独再フェッチ.
    /// 同日 2 回目以降は no-op (コーデ無限再生成の防止).
    func updatePrefecture(_ prefecture: Prefecture) async {
        guard canChangePrefectureToday else {
            ToastManager.shared.show("お住まいの地域は1日1回まで変更できます")
            return
        }
        // 同じ県を選び直した場合も lastChanged を消費させない
        guard prefecture.code != currentPrefectureCode else { return }

        UserDefaults.standard.set(prefecture.code, forKey: UserDefaultsKey.prefectureCode.rawValue)
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKey.prefectureLastChangedAt.rawValue)
        currentPrefectureCode = prefecture.code

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        if !uid.isEmpty {
            _ = try? await updatePrefectureClient.put(uid: uid, prefectureCode: prefecture.code)
        }
        await refreshDailyRecommendation()
    }

    /// daily-recommendation のみ再取得 (recent_coordinates 等はそのまま)
    func refreshDailyRecommendation() async {
        isLoadingDailyRecommendation = true
        hasDailyRecommendationError = false

        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        do {
            switch try await dailyRecommendationClient.get(uid: uid, gender: gender) {
            case .success(let response):
                dailyRecommendation = response
            case .failure:
                hasDailyRecommendationError = true
            }
        } catch {
            hasDailyRecommendationError = true
        }
        isLoadingDailyRecommendation = false
    }

    /// 「これを今日着る」マーク
    func markWorn(item: DailyRecommendationItem) async -> Bool {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let today = formatter.string(from: Date())
        do {
            let result = try await dailyRecommendationClient.markWorn(
                uid: uid, poolId: item.pool_id, wornDate: today
            )
            switch result {
            case .success: return true
            case .failure: return false
            }
        } catch {
            return false
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
        let userGender = UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue) ?? "men"
        selectCoordinateItemsByDate[dateID] = SelectCoordinateItem(
            gender: selectCoordinateItemsByDate[dateID]?.gender ?? userGender,
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
                    ToastManager.shared.show(response.message ?? "削除に失敗しました")
                }
            case .failure(let error):
                ToastManager.shared.show(error.errorDescription ?? "削除に失敗しました")
            }
        } catch {
            ToastManager.shared.show("削除に失敗しました")
        }
    }
}
