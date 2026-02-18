//
//  HomePlannerCacheRepository.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/18.
//

import Foundation

struct PlannerDayCache: Codable {
    let dateString: String  // "yyyy-MM-dd"
    let coordinates: [CoordinateRecommend]
    let selectedItem: SelectCoordinateItem?
}

protocol HomePlannerCacheRepositoryProtocol {
    func save(_ cache: PlannerDayCache)
    func load(dateString: String) -> PlannerDayCache?
}

final class HomePlannerCacheRepository: HomePlannerCacheRepositoryProtocol {
    private let userDefaultsManager: UserDefaultsManagerProtocol

    init(userDefaultsManager: UserDefaultsManagerProtocol = UserDefaultsManager()) {
        self.userDefaultsManager = userDefaultsManager
    }

    func save(_ cache: PlannerDayCache) {
        var all = loadAll()
        if let index = all.firstIndex(where: { $0.dateString == cache.dateString }) {
            all[index] = cache
        } else {
            all.append(cache)
        }
        // 3日分より古いエントリを削除
        let validDates = validDateStrings()
        all = all.filter { validDates.contains($0.dateString) }
        userDefaultsManager.save(all, forKey: .homePlannerCache)
    }

    func load(dateString: String) -> PlannerDayCache? {
        return loadAll().first { $0.dateString == dateString }
    }

    private func loadAll() -> [PlannerDayCache] {
        return userDefaultsManager.load([PlannerDayCache].self, forKey: .homePlannerCache) ?? []
    }

    /// 今日〜明後日の日付文字列セット
    private func validDateStrings() -> Set<String> {
        let calendar = Calendar.current
        let formatter = dateFormatter()
        return Set((0..<3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: Date()).map { formatter.string(from: $0) }
        })
    }

    static func dateString(for dateID: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dateID, to: Date()) ?? Date()
        return dateFormatter().string(from: date)
    }

    private static func dateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }

    private func dateFormatter() -> DateFormatter {
        return Self.dateFormatter()
    }
}
