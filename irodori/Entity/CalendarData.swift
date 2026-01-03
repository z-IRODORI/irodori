//
//  CalendarData.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/03.
//

import Foundation

struct CalendarData: Identifiable, Hashable {
    let id: Int
    let date: Date
    var dayString: String { date.formatted(.dateTime.day()) }
    var weekDayString: String { date.formatted(.dateTime.weekday(.abbreviated)) }
}
