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

struct ProfileInfo: Codable, Identifiable {
    var id: String
    var username: String
    var displayName: String
    var profileImageUrl: String?
    var createdAt: Date
    var lastLoginAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case profileImageUrl = "profile_image_url"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
    }

    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }

    var formattedLastLoginAt: String? {
        guard let lastLoginAt = lastLoginAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: lastLoginAt)
    }
}
