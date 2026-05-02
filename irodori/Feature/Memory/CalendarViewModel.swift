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

    let apiClient: CoordinateListClientProtocol

    init(apiClient: CoordinateListClientProtocol) {
        self.apiClient = apiClient
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
        monthStates.contains {
            if case .loaded(let responses) = $0 {
                return responses.contains { $0.coodinate_image_path != nil }
            }
            return false
        }
    }

    func onAppear() async {
        guard !hasLoaded else {
            return
        }

        setupMonths()
        // スケルトンで即座に全月を表示するため先にstatesを確保
        monthStates = Array(repeating: .loading, count: months.count)

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

        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
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
