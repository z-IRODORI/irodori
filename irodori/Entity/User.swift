//
//  User.swift
//  irodori
//
//  Created by Claude on 2025/07/07.
//

import Foundation

enum Gender: String, CaseIterable, Codable {
    case male = "男性"
    case female = "女性"
    case other = "その他"

    var number: Int {
        switch self {
        case .male: return 0
        case .female: return 1
        case .other: return 2
        }
    }
}

struct BirthDay: Codable {
    var year: String
    var month: String
    var day: String
}

struct User: Codable {
    var username: String
    var birthday: BirthDay
    var gender: Gender
}
