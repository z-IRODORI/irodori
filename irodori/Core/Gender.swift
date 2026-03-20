//
//  Gender.swift
//  irodori
//
//  Created by Claude on 2026/03/20.
//

import Foundation

enum Gender: String, Codable {
    case men = "men"
    case women = "women"
    case other = "other"

    /// UserDefaults等から取得したStringをGenderに変換
    /// 不正な値の場合はnilを返す
    static func from(_ string: String?) -> Gender? {
        guard let string = string else { return nil }
        return Gender(rawValue: string)
    }

    /// UserDefaults等から取得したStringをGenderに変換
    /// 不正な値の場合はデフォルト値を返す
    static func fromWithDefault(_ string: String?, default: Gender = .other) -> Gender {
        guard let string = string,
              let gender = Gender(rawValue: string) else {
            return `default`
        }
        return gender
    }
}
