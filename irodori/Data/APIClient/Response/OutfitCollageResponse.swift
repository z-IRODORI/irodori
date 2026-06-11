//
//  OutfitCollageResponse.swift
//  irodori
//
//  コーデコラージュ (クローゼットでコーデ) APIのレスポンス
//

import Foundation

struct OutfitCollageItem: Decodable, Hashable, Identifiable {
    let id: String             // closet item id (標準アイテム補完時は standard item id)
    let slot: String           // tops / bottoms / outer / shoes / accessory / bag
    let item_type: String      // "トップス" など (表記揺れあり)
    let category: String?
    let color: String?
    let image_url: String
    let is_standard: Bool      // 標準アイテム補完なら true

    var slotDisplayName: String {
        switch slot {
        case "tops": return "トップス"
        case "bottoms": return "ボトムス"
        case "outer": return "アウター"
        case "shoes": return "シューズ"
        case "bag": return "バッグ"
        case "accessory": return "アクセサリー"
        default: return slot
        }
    }

    /// 表示用: カテゴリ (なければ item_type) + 色
    var displayName: String {
        let name = category ?? item_type
        if let color, !color.isEmpty {
            return "\(color) / \(name)"
        }
        return name
    }

    enum CodingKeys: String, CodingKey {
        case id, slot, item_type, category, color, image_url, is_standard
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.slot = try c.decode(String.self, forKey: .slot)
        self.item_type = (try? c.decode(String.self, forKey: .item_type)) ?? ""
        self.category = try? c.decode(String.self, forKey: .category)
        self.color = try? c.decode(String.self, forKey: .color)
        self.image_url = (try? c.decode(String.self, forKey: .image_url)) ?? ""
        self.is_standard = (try? c.decode(Bool.self, forKey: .is_standard)) ?? false
    }

    // mock 用 memberwise init
    init(id: String, slot: String, item_type: String, category: String?, color: String?,
         image_url: String, is_standard: Bool = false) {
        self.id = id
        self.slot = slot
        self.item_type = item_type
        self.category = category
        self.color = color
        self.image_url = image_url
        self.is_standard = is_standard
    }
}

struct OutfitCollageResponse: Decodable, Hashable {
    let status: String                              // success | partial | failed
    let collage_id: String
    let collage_url: String
    let items: [OutfitCollageItem]                  // コラージュに使われたアイテム
    let candidates: [String: [OutfitCollageItem]]   // slot -> 差し替え候補 (最大20件)

    /// 表示できる状態か (失敗時はホームのセクションごと非表示にする)
    var isDisplayable: Bool {
        status != "failed" && !collage_url.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case status, collage_id, collage_url, items, candidates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "failed"
        self.collage_id = (try? c.decode(String.self, forKey: .collage_id)) ?? ""
        self.collage_url = (try? c.decode(String.self, forKey: .collage_url)) ?? ""
        self.items = (try? c.decode([OutfitCollageItem].self, forKey: .items)) ?? []
        self.candidates = (try? c.decode([String: [OutfitCollageItem]].self, forKey: .candidates)) ?? [:]
    }

    // mock 用 memberwise init
    init(status: String, collage_id: String, collage_url: String,
         items: [OutfitCollageItem], candidates: [String: [OutfitCollageItem]]) {
        self.status = status
        self.collage_id = collage_id
        self.collage_url = collage_url
        self.items = items
        self.candidates = candidates
    }
}

// MARK: - Mock

extension OutfitCollageResponse {
    static func mock() -> Self {
        let tops = OutfitCollageItem(
            id: "t1", slot: "tops", item_type: "トップス", category: "Tシャツ",
            color: "ホワイト",
            image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg"
        )
        let bottoms = OutfitCollageItem(
            id: "b1", slot: "bottoms", item_type: "ボトムス", category: "ジーンズ",
            color: "インディゴ",
            image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg"
        )
        let shoes = OutfitCollageItem(
            id: "s1", slot: "shoes", item_type: "シューズ", category: "スニーカー",
            color: "ホワイト",
            image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg"
        )
        return .init(
            status: "success",
            collage_id: "mock-collage-id",
            collage_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg",
            items: [tops, bottoms, shoes],
            candidates: [
                "tops": [tops, OutfitCollageItem(
                    id: "t2", slot: "tops", item_type: "トップス", category: "パーカー",
                    color: "グレー",
                    image_url: "https://i.pinimg.com/736x/c9/61/92/c96192fc7e225468fbd88137717364ea.jpg"
                )],
                "bottoms": [bottoms],
                "shoes": [shoes],
            ]
        )
    }
}
