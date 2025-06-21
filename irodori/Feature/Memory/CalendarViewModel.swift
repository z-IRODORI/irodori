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
        .init(month: "12月", monthOfTheYear: 12, year: 2022),
        .init(month: "1月", monthOfTheYear: 1, year: 2023),
        .init(month: "2月", monthOfTheYear: 2, year: 2023),
        .init(month: "3月", monthOfTheYear: 3, year: 2023),
        .init(month: "4月", monthOfTheYear: 4, year: 2023),
        .init(month: "5月", monthOfTheYear: 5, year: 2023),
        .init(month: "6月", monthOfTheYear: 6, year: 2023),
        .init(month: "7月", monthOfTheYear: 7, year: 2023),
        .init(month: "8月", monthOfTheYear: 8, year: 2023),
    ]
    let daysOfTheWeek: [Week] = Week.allCases
    let hoge = ""
}

