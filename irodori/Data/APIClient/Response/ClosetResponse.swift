//
//  ClosetResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/11.
//

import Foundation

struct ClosetResponse: Codable {
    let items: [ClosetItem]
}

struct ClosetItem: Codable, Identifiable, Hashable {
    let id: String
    let item_type: String
    let category: String?
    let color: String?
    let image_url: String?
    let date: String?
    /// 柄・袖丈・素材など (相棒が写真と名前から読み取ったもの。ユーザーが直せる)
    var attrs: ClosetItemAttrs? = nil

    /// item_type の大分類部分。定番アイテムは「ボトムス_ジーンズ」のように
    /// 「大分類_小分類」で保存されているため、先頭の大分類だけを取り出す。
    /// 濁点が分かれた表記 (NFD) も同じ文字列として扱う。
    var mainItemType: String {
        let normalized = item_type.precomposedStringWithCanonicalMapping
        return normalized.split(separator: "_", maxSplits: 1).first.map(String.init) ?? normalized
    }

    // ClothingCategoryへの変換
    var clothingCategory: ClothingCategory {
        switch mainItemType {
        case "トップス":
            return .tops
        case "ボトムス":
            return .bottoms
        case "靴", "シューズ":
            return .shoes
        case "アウター":
            return .outer
        case "アクセサリー", "小物", "バッグ", "帽子":
            return .accessories
        default:
            return .tops // 未知の種別はトップス扱い (従来互換)
        }
    }
}


/// 服の特徴 (サーバの item_vocab の値)
struct ClosetItemAttrs: Codable, Hashable {
    var pattern: String?
    var sleeve: String?
    var neckline: String?
    var silhouette: String?
    var length: String?
    var material: String?
    var formality: String?
    var warmth: String?
    var style_tags: [String]?
}

/// 服の特徴を直す (PATCH /api/closet/{uid}/items/{id}/attrs)
enum ClosetAttrsClient {
    static func update(uid: String, itemId: String, attrs: [String: String]) async -> Bool {
        guard let url = URL(string: "https://irodori-api.onrender.com/api/closet/\(uid)/items/\(itemId)/attrs") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["attrs": attrs])
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }
}
