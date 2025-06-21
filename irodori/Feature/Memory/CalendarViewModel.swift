//
//  CalendarViewModel.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation

@MainActor
@Observable
final class CalendarViewModel {
    let months: [Month] = [
        .init(title: "12月", monthOfTheYear: 12, year: 2022),
        .init(title: "1月", monthOfTheYear: 1, year: 2023),
        .init(title: "2月", monthOfTheYear: 2, year: 2023),
        .init(title: "3月", monthOfTheYear: 3, year: 2023),
        .init(title: "4月", monthOfTheYear: 4, year: 2023),
        .init(title: "5月", monthOfTheYear: 5, year: 2023),
        .init(title: "6月", monthOfTheYear: 6, year: 2023),
        .init(title: "7月", monthOfTheYear: 7, year: 2023),
        .init(title: "8月", monthOfTheYear: 8, year: 2023),
    ]
    let daysOfTheWeek: [Week] = Week.allCases
    let hoge = ""
}

