//
//  HomeViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation
import SwiftUI

/// WebView シートで開く URL のラッパー（.sheet(item:) 用に Identifiable）
/// おすすめコーデへのフィードバック評価
enum PickFeedbackRating: String {
    case like
    case dislike
}

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
    // 今日/明日/週末 タブ (コーデ提案)
    var pickTabs: [PickTab] = PickTabBuilder.visibleTabs()
    var selectedPickScope: PickScope = PickTabBuilder.defaultScope()
    private(set) var dailyByScope: [PickScope: DailyRecommendationResponse] = [:]
    private var dailyLoadingScopes: Set<PickScope> = []
    private var dailyErrorScopes: Set<PickScope> = []
    private var dailyInFlight: Set<PickScope> = []
    /// このセッションでサーバ再検証済みのスコープ (ディスクキャッシュの地域陳腐化対策)
    private var dailyRevalidated: Set<PickScope> = []
    /// このセッションで送信したフィードバック (pool_id → 評価)。UI状態の即時反映用
    private(set) var feedbackByPool: [String: PickFeedbackRating] = [:]
    /// 「これにする」決定の記録 (対象日 → pool_id + 最終決定操作日)。UserDefaults 永続化
    private var decisionRecord = DecisionRecord.load()
    /// タブ間で表示上位が重複しないよう、先着スコープが表示枠 (上位3件) を確保する台帳。
    /// サーバ側の兄弟日付除外の保険 (修正前に生成された旧キャッシュ対策)
    private var claimedDisplayIDs: [PickScope: [String]] = [:]

    // 互換アクセサ (選択中スコープのデータをビューへ)
    var dailyRecommendation: DailyRecommendationResponse? { dailyByScope[selectedPickScope] }
    var isLoadingDailyRecommendation: Bool { dailyLoadingScopes.contains(selectedPickScope) }
    var hasDailyRecommendationError: Bool { dailyErrorScopes.contains(selectedPickScope) }
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
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )

        // 前回のレスポンスがあれば即描画 (stale-while-revalidate)。
        // スケルトンは「表示できる内容が無いセクション」だけに出す
        refreshPickTabsIfNeeded()
        hydrateFromCache(uid: uid)
        isLoadingHome = homeResponse.recent_coordinates.isEmpty
        isLoadingAnalysis = recentCoordinateAnalysis.isEmpty
        if dailyByScope[selectedPickScope] == nil {
            dailyLoadingScopes.insert(selectedPickScope)
        }
        isLoadingOutfitCollage = (outfitCollage == nil)
        isLoadingClosetBridge = (closetBridge == nil)
        hasLoadError = false
        dailyErrorScopes.remove(selectedPickScope)
        hasOutfitCollageError = false
        hasClosetBridgeError = false

        // 各セクションを独立に取得・反映する。
        // 旧実装は async let を固定順で await していたため、先に await される遅い呼び出し
        // (LLM分析など) が終わるまで、完了済みの後続セクションも反映されなかった
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadHomeSection(uid: uid) }
            group.addTask { await self.loadAnalysisSection(uid: uid) }
            group.addTask { await self.loadDaily(scope: self.selectedPickScope, force: true) }
            group.addTask { await self.loadCollageSection(uid: uid, gender: gender) }
            group.addTask { await self.loadClosetBridgeSection(uid: uid, gender: gender) }
            // 夜→朝ループ: 20時以降なら明日タブを先読み (ティザー表示用) し、
            // 21時のローカル通知を予約 (許可済みの場合のみ)
            group.addTask { await self.loadTomorrowTeaserIfNeeded() }
            group.addTask { await NotificationManager.shared.scheduleEveningTeaserIfNeeded() }
        }
    }

    /// 前回成功時のレスポンスを即時反映する (無ければ何もしない)
    private func hydrateFromCache(uid: String) {
        if homeResponse.recent_coordinates.isEmpty,
           let cached = HomeSectionCache.load(HomeResponse.self, section: "home", uid: uid),
           !cached.recent_coordinates.isEmpty {
            homeResponse = cached
        }
        if recentCoordinateAnalysis.isEmpty,
           let cached = HomeSectionCache.load(String.self, section: "analysis", uid: uid),
           !cached.isEmpty {
            recentCoordinateAnalysis = cached
        }
        if dailyByScope[selectedPickScope] == nil {
            hydrateDailyCache(scope: selectedPickScope, uid: uid)
        }
        if outfitCollage == nil {
            outfitCollage = HomeSectionCache.load(OutfitCollageResponse.self, section: "collage", uid: uid)
        }
        if closetBridge == nil {
            closetBridge = HomeSectionCache.load(ClosetBridgeResponse.self, section: "closetBridge", uid: uid)
        }
    }

    // MARK: - セクション別ロード (完了したものから独立に反映)

    private func loadHomeSection(uid: String) async {
        do {
            switch try await apiClient.get(uid: uid) {
            case .success(let response):
                homeResponse = response
                HomeSectionCache.save(response, section: "home", uid: uid)
            case .failure:
                if homeResponse.recent_coordinates.isEmpty { hasLoadError = true }
            }
        } catch {
            if homeResponse.recent_coordinates.isEmpty { hasLoadError = true }
        }
        isLoadingHome = false
    }

    private func loadAnalysisSection(uid: String) async {
        do {
            switch try await analyzeRecentCoordinateClient.post(uid: uid, targetDays: 7) {
            case .success(let response):
                recentCoordinateAnalysis = response.analyze_recent_coordinate
                HomeSectionCache.save(response.analyze_recent_coordinate, section: "analysis", uid: uid)
            case .failure:
                if recentCoordinateAnalysis.isEmpty {
                    recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
                }
            }
        } catch {
            if recentCoordinateAnalysis.isEmpty {
                recentCoordinateAnalysis = "コーデが存在しないため分析できませんでした"
            }
        }
        isLoadingAnalysis = false
    }

    // MARK: - 今日/明日/週末 タブ (コーデ提案)

    /// 日付が変わった場合にタブ構成を再計算する (選択中スコープが消えたら既定に戻す)
    private func refreshPickTabsIfNeeded() {
        let tabs = PickTabBuilder.visibleTabs()
        if tabs.map(\.dateString) != pickTabs.map(\.dateString) {
            pickTabs = tabs
            dailyByScope.removeAll()
            dailyRevalidated.removeAll()
            claimedDisplayIDs.removeAll()
        }
        if !tabs.contains(where: { $0.scope == selectedPickScope }) {
            selectedPickScope = PickTabBuilder.defaultScope()
        }
    }

    /// スコープ別ディスクキャッシュを (対象日が一致する場合のみ) 反映する
    private func hydrateDailyCache(scope: PickScope, uid: String) {
        guard dailyByScope[scope] == nil,
              let tab = pickTabs.first(where: { $0.scope == scope }),
              let cached = HomeSectionCache.load(
                DailyRecommendationResponse.self,
                section: "daily_\(scope.rawValue)",
                uid: uid
              ),
              cached.target_date == tab.dateString else { return }
        let cleaned = sanitizedDaily(cached)
        dailyByScope[scope] = cleaned
        claimDisplaySlots(scope: scope, response: cleaned)
    }

    /// 自分が登録したコーデ (kind=self) はおすすめに表示しない。
    /// サーバ側でも注入を止めたが、修正前に生成されたキャッシュにも即効させる
    private func sanitizedDaily(_ response: DailyRecommendationResponse) -> DailyRecommendationResponse {
        let filtered = response.recommendations.filter { $0.kind != "self" }
        guard filtered.count != response.recommendations.count else { return response }
        return DailyRecommendationResponse(
            target_date: response.target_date,
            weather: response.weather,
            partner_comment: response.partner_comment,
            recommendations: filtered,
            mode: response.mode,
            feedback_ack: response.feedback_ack,
            signal_count: response.signal_count,
            signal_caption: response.signal_caption
        )
    }

    /// 到着したスコープが表示上位3件の枠を確保する (先着優先・セッション内で安定)。
    /// 他スコープが確保済みのコーデは飛ばして次点を繰り上げる
    private func claimDisplaySlots(scope: PickScope, response: DailyRecommendationResponse) {
        let othersClaimed = Set(
            claimedDisplayIDs.filter { $0.key != scope }.values.flatMap { $0 }
        )
        let visible = response.recommendations.filter { !othersClaimed.contains($0.pool_id) }
        claimedDisplayIDs[scope] = visible.prefix(3).map(\.pool_id)
    }

    /// 表示用: 他タブが表示枠を確保したコーデを除いたリスト。
    /// タブ3つ×上位3枚の計9枚に同じコーデが2枚以上出ないことを保証する
    func displayRecommendations(for scope: PickScope) -> [DailyRecommendationItem] {
        guard let response = dailyByScope[scope] else { return [] }
        let othersClaimed = Set(
            claimedDisplayIDs.filter { $0.key != scope }.values.flatMap { $0 }
        )
        return response.recommendations.filter { !othersClaimed.contains($0.pool_id) }
    }

    /// タブ選択。未取得スコープのみ遅延ロードする (先読みはしない:
    /// サーバの表示履歴 record_shown を見ていないタブで汚さないため)
    func selectPickScope(_ scope: PickScope) {
        guard scope != selectedPickScope else { return }
        selectedPickScope = scope
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        // 対象日がずれた既存データは破棄 (日付跨ぎ対策)
        if let tab = pickTabs.first(where: { $0.scope == scope }),
           let existing = dailyByScope[scope], existing.target_date != tab.dateString {
            dailyByScope[scope] = nil
        }
        hydrateDailyCache(scope: scope, uid: uid)
        let needsFetch = dailyByScope[scope] == nil
        // ディスクキャッシュ由来のデータは1セッション1回だけサーバ再検証する
        let needsRevalidate = !dailyRevalidated.contains(scope)
        guard needsFetch || needsRevalidate else { return }
        if needsFetch { dailyLoadingScopes.insert(scope) }
        Task { await loadDaily(scope: scope, force: true) }
    }

    /// 開発用: サーバキャッシュを無視して選択中スコープを再生成する
    /// (最新のフィードバック/クローゼット/天気が即時反映される)
    func reloadDailyRecommendation() async {
        dailyByScope[selectedPickScope] = nil
        await loadDaily(scope: selectedPickScope, force: true, regenerate: true)
    }

    /// スコープ単位で daily-recommendation を取得する
    private func loadDaily(scope: PickScope, force: Bool = false, regenerate: Bool = false) async {
        guard let tab = pickTabs.first(where: { $0.scope == scope }) else { return }
        if dailyInFlight.contains(scope) { return }
        if !force, let existing = dailyByScope[scope], existing.target_date == tab.dateString { return }
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        dailyInFlight.insert(scope)
        if dailyByScope[scope] == nil { dailyLoadingScopes.insert(scope) }
        dailyErrorScopes.remove(scope)
        do {
            switch try await dailyRecommendationClient.get(
                uid: uid, gender: gender, targetDate: tab.dateString, forceRegenerate: regenerate
            ) {
            case .success(let response):
                let cleaned = sanitizedDaily(response)
                dailyByScope[scope] = cleaned
                claimDisplaySlots(scope: scope, response: cleaned)
                dailyRevalidated.insert(scope)
                HomeSectionCache.save(cleaned, section: "daily_\(scope.rawValue)", uid: uid)
                // 明日タブが取れたら、21時のローカル通知の文言を相棒コメントに差し替える
                if scope == .tomorrow {
                    Task { await NotificationManager.shared.scheduleEveningTeaser(body: cleaned.partner_comment) }
                }
            case .failure:
                if dailyByScope[scope] == nil { dailyErrorScopes.insert(scope) }
            }
        } catch {
            if dailyByScope[scope] == nil { dailyErrorScopes.insert(scope) }
        }
        dailyLoadingScopes.remove(scope)
        dailyInFlight.remove(scope)
    }

    private func loadCollageSection(uid: String, gender: Gender) async {
        do {
            switch try await outfitCollageClient.get(uid: uid, gender: gender) {
            case .success(let response):
                outfitCollage = response
                HomeSectionCache.save(response, section: "collage", uid: uid)
            case .failure:
                if outfitCollage == nil { hasOutfitCollageError = true }
            }
        } catch {
            if outfitCollage == nil { hasOutfitCollageError = true }
        }
        isLoadingOutfitCollage = false
    }

    private func loadClosetBridgeSection(uid: String, gender: Gender) async {
        do {
            switch try await closetBridgeClient.get(uid: uid, gender: gender) {
            case .success(let response):
                closetBridge = response
                HomeSectionCache.save(response, section: "closetBridge", uid: uid)
            case .failure:
                if closetBridge == nil { hasClosetBridgeError = true }
            }
        } catch {
            if closetBridge == nil { hasClosetBridgeError = true }
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
        // 地域が変わると全スコープの天気・提案が変わるため作り直す
        dailyByScope.removeAll()
        dailyRevalidated.removeAll()
        claimedDisplayIDs.removeAll()
        await refreshDailyRecommendation()
    }

    /// 選択中スコープの daily-recommendation のみ再取得 (エラー再試行・地域変更用)
    func refreshDailyRecommendation() async {
        await loadDaily(scope: selectedPickScope, force: true)
    }

    /// 「これを着る」マーク。選択中タブの対象日 (今日/明日/週末) に記録する
    func markWorn(item: DailyRecommendationItem) async -> Bool {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd"
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let wornDate = dailyRecommendation?.target_date ?? fallbackFormatter.string(from: Date())
        do {
            let result = try await dailyRecommendationClient.markWorn(
                uid: uid, poolId: item.pool_id, wornDate: wornDate
            )
            switch result {
            case .success: return true
            case .failure: return false
            }
        } catch {
            return false
        }
    }

    // MARK: - 「これにする」決定の記録 (決定の儀式・ティザー解放)

    /// 対象日 → pool_id と最終決定操作日。翌朝は日付が変わることで自然リセットされる
    private struct DecisionRecord: Codable {
        var byDate: [String: String] = [:]
        var lastActionDate: String? = nil

        static func load() -> DecisionRecord {
            guard let data = UserDefaults.standard.data(
                forKey: UserDefaultsKey.dailyDecisionRecord.rawValue
            ), let record = try? JSONDecoder().decode(DecisionRecord.self, from: data) else {
                return DecisionRecord()
            }
            return record
        }

        func save() {
            if let data = try? JSONEncoder().encode(self) {
                UserDefaults.standard.set(data, forKey: UserDefaultsKey.dailyDecisionRecord.rawValue)
            }
        }
    }

    static func jstTodayString(now: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return fmt.string(from: now)
    }

    /// 対象日に「これにする」済みの pool_id (無ければ nil)
    func decidedPoolId(forDate dateString: String) -> String? {
        decisionRecord.byDate[dateString]
    }

    /// 今日 (JST) にどれかのタブで決定操作をしたか (ティザーのぼかし解放に使う)
    var hasDecidedToday: Bool {
        decisionRecord.lastActionDate == Self.jstTodayString()
    }

    /// 「これにする」成功時に呼ぶ。決定を永続化する (再決定は上書き)
    func recordDecision(poolId: String, targetDate: String) {
        decisionRecord.byDate[targetDate] = poolId
        decisionRecord.lastActionDate = Self.jstTodayString()
        // 過去日のエントリは自然に不要になるため間引く (直近14日ぶんだけ保持)
        if decisionRecord.byDate.count > 14 {
            let sorted = decisionRecord.byDate.keys.sorted(by: >)
            for key in sorted.dropFirst(14) {
                decisionRecord.byDate.removeValue(forKey: key)
            }
        }
        decisionRecord.save()
    }

    // MARK: - 20時ティザー (夜→朝ループ)

    /// JST 20時以降か (ティザーの表示条件)
    var isEveningTeaserTime: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        return cal.component(.hour, from: Date()) >= 20
    }

    /// ティザーに使う明日タブのレスポンス (未取得なら nil)
    var teaserResponse: DailyRecommendationResponse? { dailyByScope[.tomorrow] }

    /// 20時以降にホームを開いたとき、明日タブ未取得なら先読みする (ティザー表示用)
    func loadTomorrowTeaserIfNeeded() async {
        guard isEveningTeaserTime, dailyByScope[.tomorrow] == nil else { return }
        await loadDaily(scope: .tomorrow)
    }

    // MARK: - おすすめコーデへのフィードバック (パーソナライズ改善)

    func feedbackRating(for item: DailyRecommendationItem) -> PickFeedbackRating? {
        feedbackByPool[item.pool_id]
    }

    /// フィードバックを送信する。dislike は成功時に全スコープの表示からも即時除去する
    /// (サーバ側でもキャッシュ除去+候補ハード除外+テイスト負シグナルに反映される)
    func sendFeedback(
        item: DailyRecommendationItem,
        rating: PickFeedbackRating,
        reasons: [String] = []
    ) async -> Bool {
        // closet 種別は pool_id がプールを指さないため対象外
        guard !item.isCloset else { return false }
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        let targetDate = dailyRecommendation?.target_date
        do {
            switch try await dailyRecommendationClient.postFeedback(
                uid: uid,
                poolId: item.pool_id,
                rating: rating.rawValue,
                reasons: reasons,
                targetDate: targetDate
            ) {
            case .success:
                feedbackByPool[item.pool_id] = rating
                if rating == .dislike {
                    removeRecommendationEverywhere(poolID: item.pool_id)
                }
                return true
            case .failure:
                return false
            }
        } catch {
            return false
        }
    }

    /// dislike されたコーデを全スコープの表示・ローカルキャッシュから取り除く
    private func removeRecommendationEverywhere(poolID: String) {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        for (scope, response) in dailyByScope {
            let filtered = response.recommendations.filter { $0.pool_id != poolID }
            guard filtered.count != response.recommendations.count else { continue }
            let updated = DailyRecommendationResponse(
                target_date: response.target_date,
                weather: response.weather,
                partner_comment: response.partner_comment,
                recommendations: filtered,
                mode: response.mode,
                feedback_ack: response.feedback_ack,
                signal_count: response.signal_count,
                signal_caption: response.signal_caption
            )
            dailyByScope[scope] = updated
            HomeSectionCache.save(updated, section: "daily_\(scope.rawValue)", uid: uid)
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
