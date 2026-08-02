//
//  CalendarViewModel.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation
import Observation

enum MonthLoadState {
    case loading
    case loaded([CoordinateListResponse])
    case failed
}

@MainActor
@Observable
final class CalendarViewModel {
    var months: [Month] = []
    var monthStates: [MonthLoadState] = []
    let daysOfTheWeek: [Week] = Week.allCases
    let uid: String
    var hasLoaded = false

    /// 予定コーデ ("YYYY-MM-DD" -> CalendarOutfit)。着用記録とは別レイヤーで重ねる
    var plannedByDate: [String: CalendarOutfit] = [:]

    let apiClient: CoordinateListClientProtocol
    private let calendarOutfitClient: CalendarOutfitClientProtocol
    private let poolClient: RecommendationPoolClientProtocol
    private let dailyClient: DailyRecommendationClientProtocol

    init(
        apiClient: CoordinateListClientProtocol,
        calendarOutfitClient: CalendarOutfitClientProtocol = CalendarOutfitClient(),
        poolClient: RecommendationPoolClientProtocol = RecommendationPoolClient(),
        dailyClient: DailyRecommendationClientProtocol = DailyRecommendationClient()
    ) {
        self.apiClient = apiClient
        self.calendarOutfitClient = calendarOutfitClient
        self.poolClient = poolClient
        self.dailyClient = dailyClient
        self.uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        setupMonths()
    }

    var isInitiallyLoading: Bool {
        !monthStates.isEmpty && monthStates.allSatisfy {
            if case .loading = $0 { return true }
            return false
        }
    }

    var allLoaded: Bool {
        !monthStates.isEmpty && monthStates.allSatisfy {
            if case .loading = $0 { return false }
            return true
        }
    }

    var hasAnyCoordinates: Bool {
        if !plannedByDate.isEmpty { return true }
        return monthStates.contains {
            if case .loaded(let responses) = $0 {
                return responses.contains { $0.coodinate_image_path != nil }
            }
            return false
        }
    }

    // MARK: - 予定コーデ

    func planned(year: Int, month: Int, day: Int) -> CalendarOutfit? {
        plannedByDate[String(format: "%04d-%02d-%02d", year, month, day)]
    }

    func hasPlanned(year: Int, month: Int) -> Bool {
        let prefix = String(format: "%04d-%02d-", year, month)
        return plannedByDate.keys.contains { $0.hasPrefix(prefix) }
    }

    /// 今日以降の予定コーデ日数 (プランナー導線の残弾表示用)。
    /// "YYYY-MM-DD" は辞書順 = 日付順なので文字列比較で数えられる
    var upcomingPlannedCount: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let today = formatter.string(from: Date())
        return plannedByDate.keys.filter { $0 >= today }.count
    }

    /// 予定コーデを取得 (先月〜来月の3ヶ月分。予定は近い日付にしか存在しない想定)
    func loadPlanned() async {
        guard !uid.isEmpty else { return }
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        var merged: [String: CalendarOutfit] = [:]
        for offset in -1...1 {
            guard let target = calendar.date(byAdding: .month, value: offset, to: base) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: target)
            guard let year = comps.year, let month = comps.month else { continue }
            if let result = try? await calendarOutfitClient.list(uid: uid, year: year, month: month),
               case .success(let response) = result {
                for item in response.items {
                    merged[item.date] = item
                }
            }
        }
        plannedByDate = merged
    }

    func deletePlanned(_ outfit: CalendarOutfit) async -> Bool {
        guard let result = try? await calendarOutfitClient.delete(uid: uid, date: outfit.date),
              case .success = result else {
            ToastManager.shared.show("予定の削除に失敗しました")
            return false
        }
        plannedByDate.removeValue(forKey: outfit.date)
        return true
    }

    /// 予定コーデ (kind=pool) の詳細アイテムを取得。失敗時は最低限の表示用フォールバック
    func fetchPoolItem(_ outfit: CalendarOutfit) async -> DailyRecommendationItem {
        if let result = try? await poolClient.get(poolId: outfit.target_id, uid: uid),
           case .success(let item) = result {
            return item
        }
        return DailyRecommendationItem(
            pool_id: outfit.target_id,
            kind: "pool",
            image_url: outfit.image_url,
            reason: nil,
            main_colors: [],
            items: [:],
            vibe: "",
            style: "",
            cleanliness: 3,
            is_favorite: false
        )
    }

    /// 詳細モーダルの「これを今日着る」用 (着用実績の記録)
    func markWornToday(_ item: DailyRecommendationItem) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let today = formatter.string(from: Date())
        guard let result = try? await dailyClient.markWorn(uid: uid, poolId: item.pool_id, wornDate: today),
              case .success = result else { return false }
        return true
    }

    func onAppear() async {
        guard !hasLoaded else {
            return
        }

        setupMonths()
        // スケルトンで即座に全月を表示するため先にstatesを確保
        monthStates = Array(repeating: .loading, count: months.count)

        // 予定コーデはコーデ一覧と並行して取得
        Task { await loadPlanned() }

        let uid = self.uid
        let monthsCopy = self.months
        let apiClient = self.apiClient

        await withTaskGroup(of: (Int, MonthLoadState).self) { group in
            for (i, month) in monthsCopy.enumerated() {
                group.addTask {
                    do {
                        let result = try await apiClient.get(uid: uid, year: month.year, month: month.monthOfTheYear)
                        switch result {
                        case .success(let responses):
                            return (i, .loaded(responses))
                        case .failure:
                            return (i, .failed)
                        }
                    } catch {
                        return (i, .failed)
                    }
                }
            }

            // 完了した月から順次反映 → プログレッシブ表示
            for await (i, state) in group {
                if i < monthStates.count {
                    monthStates[i] = state
                }
            }
        }

        hasLoaded = true
    }

    private func setupMonths(repository: SignUpDateRepositoryProtocol = SignUpDateRepository()) {
        self.months = []
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        let loadedSignupDate = repository.load()
        let signupDate = loadedSignupDate ?? calendar.date(byAdding: .year, value: -1, to: today)!

        // 予定コーデ (未来日) をストックできるよう、来月分までグリッドを描画する
        let displayEnd = calendar.date(byAdding: .month, value: 1, to: today) ?? today

        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: displayEnd))
        else {
            let components = calendar.dateComponents([.year, .month], from: today)
            if let year = components.year, let month = components.month {
                self.months = [Month(title: "\(month)月", monthOfTheYear: month, year: year)]
            }
            return
        }

        var date = startDate
        var monthList: [Month] = []

        while date <= endDate {
            let components = calendar.dateComponents([.year, .month], from: date)
            if let year = components.year, let month = components.month {
                monthList.append(Month(title: "\(month)月", monthOfTheYear: month, year: year))
            }
            date = calendar.date(byAdding: .month, value: 1, to: date)!
        }
        self.months = monthList.reversed()
    }
}
