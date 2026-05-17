//
//  Favorite.swift
//  irodori
//
//  お気に入りコーデの Entity. kind=pool は推薦母集団 (pool_id),
//  kind=self はユーザー自身のコーデ (coordinate_id).
//

import Foundation

enum FavoriteKind: String, Codable, Hashable, CaseIterable {
    case pool
    case `self` = "self"

    var displayName: String {
        switch self {
        case .pool: return "おすすめコーデ"
        case .self: return "自分のコーデ"
        }
    }
}

struct Favorite: Codable, Hashable, Identifiable {
    let fav_id: String
    let kind: String         // "pool" | "self"
    let target_id: String
    let image_url: String?
    let created_at: String?

    var id: String { fav_id }

    var kindEnum: FavoriteKind {
        FavoriteKind(rawValue: kind) ?? .pool
    }

    static func favId(kind: FavoriteKind, targetId: String) -> String {
        "\(kind.rawValue)_\(targetId)"
    }
}
