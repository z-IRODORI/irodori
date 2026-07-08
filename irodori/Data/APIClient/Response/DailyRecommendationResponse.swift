//
//  DailyRecommendationResponse.swift
//  irodori
//
//  明日のコーデ推薦APIのレスポンス
//

import Foundation

/// 推薦コーデに使われている手持ちアイテム (クローゼット一致)
struct DailyOwnedItem: Codable, Hashable {
    let slot: String           // tops | bottoms
    let item_id: String
    let image_url: String
    let label: String          // 例: "グレー スウェット"
}

struct DailyRecommendationItem: Codable, Hashable, Identifiable {
    var id: String { "\(kind)_\(pool_id)" }
    let pool_id: String        // kind=pool: pool_id / kind=self: coordinate_id
    let kind: String           // "pool" | "self"
    let image_url: String
    let reason: String?
    let main_colors: [String]
    let items: [String: String?]
    let vibe: String
    let style: String          // backend: genre
    let cleanliness: Int
    let is_favorite: Bool
    let owned_items: [DailyOwnedItem]   // クローゼットにある一致アイテム
    let missing_items: [String]         // 足りないアイテム (例: "黒 スラックス")

    var kindEnum: FavoriteKind {
        FavoriteKind(rawValue: kind) ?? .pool
    }

    // 旧フィールドを持たない古い response との互換性
    enum CodingKeys: String, CodingKey {
        case pool_id, kind, image_url, reason, main_colors, items, vibe, style, cleanliness, is_favorite
        case owned_items, missing_items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pool_id = try c.decode(String.self, forKey: .pool_id)
        self.kind = (try? c.decode(String.self, forKey: .kind)) ?? "pool"
        self.image_url = try c.decode(String.self, forKey: .image_url)
        self.reason = try? c.decode(String.self, forKey: .reason)
        self.main_colors = (try? c.decode([String].self, forKey: .main_colors)) ?? []
        self.items = (try? c.decode([String: String?].self, forKey: .items)) ?? [:]
        self.vibe = (try? c.decode(String.self, forKey: .vibe)) ?? ""
        self.style = (try? c.decode(String.self, forKey: .style)) ?? ""
        self.cleanliness = (try? c.decode(Int.self, forKey: .cleanliness)) ?? 3
        self.is_favorite = (try? c.decode(Bool.self, forKey: .is_favorite)) ?? false
        self.owned_items = (try? c.decode([DailyOwnedItem].self, forKey: .owned_items)) ?? []
        self.missing_items = (try? c.decode([String].self, forKey: .missing_items)) ?? []
    }

    // mock 用 memberwise init
    init(pool_id: String, kind: String = "pool", image_url: String, reason: String?, main_colors: [String], items: [String: String?], vibe: String, style: String, cleanliness: Int, is_favorite: Bool = false, owned_items: [DailyOwnedItem] = [], missing_items: [String] = []) {
        self.pool_id = pool_id
        self.kind = kind
        self.image_url = image_url
        self.reason = reason
        self.main_colors = main_colors
        self.items = items
        self.vibe = vibe
        self.style = style
        self.cleanliness = cleanliness
        self.is_favorite = is_favorite
        self.owned_items = owned_items
        self.missing_items = missing_items
    }
}

struct DailyRecommendationWeather: Codable, Hashable {
    let min_temp: Int
    let max_temp: Int
    let condition: String
    let area_code: String
}

struct DailyRecommendationResponse: Codable, Hashable {
    let target_date: String        // YYYY-MM-DD
    let weather: DailyRecommendationWeather
    let partner_comment: String?
    let recommendations: [DailyRecommendationItem]
    let mode: String               // "cached" | "fallback" | "refreshing"
}

struct WearMarkResponse: Codable {
    let status: String
    let pool_id: String
    let worn_date: String
}

// MARK: - Mock

extension DailyRecommendationResponse {
    static func mock() -> Self {
        .init(
            target_date: "2026-05-14",
            weather: .init(min_temp: 16, max_temp: 23, condition: "晴れ時々曇り", area_code: "130000"),
            partner_comment: "明日は過ごしやすいから、ライトに春らしくいこう！",
            recommendations: (1...9).map { i in
                .init(
                    pool_id: "m_\(String(format: "%04d", i))",
                    image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg",
                    reason: "Sample reason \(i)",
                    main_colors: ["white", "navy"],
                    items: ["tops": "白Tシャツ", "bottoms": "ネイビーパンツ", "outer": nil, "accessory": nil],
                    vibe: "Sample vibe \(i)",
                    style: "casual",
                    cleanliness: (i % 5) + 1
                )
            },
            mode: "cached"
        )
    }
}
