//
//  Date+extension.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import Foundation

extension Date {
    func dayNumberOfWeek() -> Int? {
        return Calendar.current.dateComponents([.weekday], from: self).weekday
    }
}
