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

    init(repository: SignUpDateRepositoryProtocol = SignUpDateRepository()) {
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        // 年月を一意にするために最初の日に合わせる
        guard let signupDate = repository.load(),
              let startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: signupDate)),
              let endDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else {
            // TODO: エラー表示
            self.months = []
            return
        }

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
        self.months = monthList
    }
}

