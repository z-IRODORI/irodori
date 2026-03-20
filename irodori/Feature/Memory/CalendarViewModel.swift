//
//  CalendarViewModel.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    var months: [Month] = []
    let daysOfTheWeek: [Week] = Week.allCases
    var coordinateListResponses: [[CoordinateListResponse]] = []
    let uid: String
    var isLoading = false
    var hasLoaded = false

    let apiClient: CoordinateListClientProtocol
    init(apiClient: CoordinateListClientProtocol) {
        self.apiClient = apiClient
        // userIdがnilの場合、空文字列を使用（APIリクエストは失敗するが、クラッシュは防げる）
        self.uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        setupMonths()
    }

    var hasAnyCoordinates: Bool {
        coordinateListResponses.contains { responses in
            responses.contains { $0.coodinate_image_path != nil }
        }
    }

    func onAppear() async {
        print("=== CalendarViewModel onAppear ===")

        // 既にロード済みの場合はスキップ
        if hasLoaded {
            print("Already loaded, skipping...")
            print("=================================")
            return
        }

        isLoading = true
        setupMonths()
        print("months count: \(months.count)")
        print("months: \(months.map { "\($0.year)-\($0.monthOfTheYear)" })")
        print("uid: \(uid)")

        coordinateListResponses = []
        do {
            // monthsは既に反転されているので、そのまま順番に取得
            for month in months {
                print("Fetching coordinates for \(month.year)-\(month.monthOfTheYear)")
                let result = try await apiClient.get(uid: uid, year: month.year, month: month.monthOfTheYear)
                switch result {
                case .success(let response):
                    print("Success: got \(response.count) coordinates")
                    coordinateListResponses.append(response)
                case .failure(let error):
                    print("Failure: \(error)")
                }
            }
            print("coordinateListResponses count: \(coordinateListResponses.count)")
        } catch {
            print("Error in onAppear: \(error)")
        }

        isLoading = false
        hasLoaded = true
        print("=================================")
    }

    private func setupMonths(repository: SignUpDateRepositoryProtocol = SignUpDateRepository()) {
        print("=== setupMonths ===")
        self.months = []
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        // signupDateがnilの場合、デフォルトで1年前を使用
        let loadedSignupDate = repository.load()
        print("loadedSignupDate: \(loadedSignupDate?.description ?? "nil")")
        let signupDate = loadedSignupDate ?? calendar.date(byAdding: .year, value: -1, to: today)!
        print("signupDate (with fallback): \(signupDate)")

        // 年月を一意にするために最初の日に合わせる
        guard let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else {
            print("Failed to create startDate or endDate, using fallback")
            // エラーが発生した場合、最低限今月だけは表示
            let components = calendar.dateComponents([.year, .month], from: today)
            if let year = components.year, let month = components.month {
                self.months = [Month(title: "\(month)月", monthOfTheYear: month, year: year)]
                print("Fallback: created 1 month - \(year)-\(month)")
            }
            return
        }

        print("startDate: \(startDate), endDate: \(endDate)")

        var date = startDate
        var monthList: [Month] = []

        while date <= endDate {
            let components = calendar.dateComponents([.year, .month], from: date)
            if let year = components.year, let month = components.month {
                let title = "\(month)月"
                monthList.append(Month(title: title, monthOfTheYear: month, year: year))
            }

            // 次の月へ進める
            date = calendar.date(byAdding: .month, value: 1, to: date)!
        }
        // 新しい月を上に表示するために反転
        self.months = monthList.reversed()
        print("Created \(self.months.count) months")
        print("===================")
    }
}

