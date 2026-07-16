//
//  OutfitCollageLayoutResponse.swift
//  irodori
//
//  コーデコラージュ配置編集 (GET/POST /api/outfit-collage/layout) のレスポンス。
//  座標は 900x1200 キャンバスに対する正規化値 (左上原点, 0-1)。
//  r は表示上の時計回り角度 (度)、hidden は「かくす」で合成から除外したアイテム。
//

import Foundation

struct OutfitCollageLayoutItem: Codable, Identifiable, Hashable {
    let id: String            // closet item id
    let slot: String          // tops / bottoms / outer / shoes / accessory / bag
    let layer_url: String     // 背景ノックアウト済み透過 PNG
    var x: Double             // 左上 X (0-1)
    var y: Double             // 左上 Y (0-1)
    var w: Double             // 幅 (0-1)
    var h: Double             // 高さ (0-1)
    var z: Int                // 重なり順 (小さいほど下)
    var r: Double             // 回転 (度, 時計回り, 中心回り)
    var hidden: Bool          // true で合成から除外 (「かくす」)

    init(id: String, slot: String, layer_url: String,
         x: Double, y: Double, w: Double, h: Double, z: Int,
         r: Double = 0, hidden: Bool = false) {
        self.id = id
        self.slot = slot
        self.layer_url = layer_url
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.z = z
        self.r = r
        self.hidden = hidden
    }

    // 旧サーバー (r/hidden 無し) のレスポンスとも後方互換で decode する
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slot = try c.decode(String.self, forKey: .slot)
        layer_url = try c.decode(String.self, forKey: .layer_url)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        w = try c.decode(Double.self, forKey: .w)
        h = try c.decode(Double.self, forKey: .h)
        z = try c.decode(Int.self, forKey: .z)
        r = try c.decodeIfPresent(Double.self, forKey: .r) ?? 0
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }
}

struct OutfitCollageLayoutResponse: Codable {
    let status: String        // success | failed
    let collage_id: String
    let canvas_w: Int
    let canvas_h: Int
    let background_color: String                   // 保存済みの背景色 "#RRGGBB"
    let items: [OutfitCollageLayoutItem]           // 現在の配置 (保存済み編集 or デフォルト)
    let default_items: [OutfitCollageLayoutItem]   // デフォルト配置 (リセット用)

    init(status: String, collage_id: String, canvas_w: Int, canvas_h: Int,
         background_color: String = "#FFFFFF",
         items: [OutfitCollageLayoutItem], default_items: [OutfitCollageLayoutItem]) {
        self.status = status
        self.collage_id = collage_id
        self.canvas_w = canvas_w
        self.canvas_h = canvas_h
        self.background_color = background_color
        self.items = items
        self.default_items = default_items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        collage_id = try c.decode(String.self, forKey: .collage_id)
        canvas_w = try c.decode(Int.self, forKey: .canvas_w)
        canvas_h = try c.decode(Int.self, forKey: .canvas_h)
        background_color = try c.decodeIfPresent(String.self, forKey: .background_color) ?? "#FFFFFF"
        items = try c.decode([OutfitCollageLayoutItem].self, forKey: .items)
        default_items = try c.decode([OutfitCollageLayoutItem].self, forKey: .default_items)
    }
}

extension OutfitCollageLayoutResponse {
    static func mock() -> OutfitCollageLayoutResponse {
        .init(
            status: "success",
            collage_id: "mock-collage",
            canvas_w: 900,
            canvas_h: 1200,
            items: [
                .init(id: "t1", slot: "tops", layer_url: "https://example.com/tops.png",
                      x: 0.22, y: 0.06, w: 0.56, h: 0.42, z: 1),
                .init(id: "b1", slot: "bottoms", layer_url: "https://example.com/bottoms.png",
                      x: 0.30, y: 0.44, w: 0.40, h: 0.48, z: 0),
            ],
            default_items: [
                .init(id: "t1", slot: "tops", layer_url: "https://example.com/tops.png",
                      x: 0.22, y: 0.06, w: 0.56, h: 0.42, z: 1),
                .init(id: "b1", slot: "bottoms", layer_url: "https://example.com/bottoms.png",
                      x: 0.30, y: 0.44, w: 0.40, h: 0.48, z: 0),
            ]
        )
    }
}
