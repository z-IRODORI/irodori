//
//  Month.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation

struct Month: Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var monthOfTheYear: Int = 0
    var year: Int = 0

    var amountOfDays:Int {
        let dateComponents = DateComponents(year: year, month: monthOfTheYear)
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!

        let range = calendar.range(of: .day, in: .month, for: date)!
        let numDays = range.count
        return numDays
    }
    var spacesBeforeFirst:Int {
        let dateComponents = DateComponents(year: year, month: monthOfTheYear)
        let calendar = Calendar.current
        let date = calendar.date(from: dateComponents)!

        return date.dayNumberOfWeek()!
    }
}
