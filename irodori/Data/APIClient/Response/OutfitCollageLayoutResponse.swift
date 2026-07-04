//
//  OutfitCollageLayoutResponse.swift
//  irodori
//
//  コーデコラージュ配置編集 (GET/POST /api/outfit-collage/layout) のレスポンス。
//  座標は 900x1200 キャンバスに対する正規化値 (左上原点, 0-1)。
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
}

struct OutfitCollageLayoutResponse: Codable {
    let status: String        // success | failed
    let collage_id: String
    let canvas_w: Int
    let canvas_h: Int
    let items: [OutfitCollageLayoutItem]           // 現在の配置 (保存済み編集 or デフォルト)
    let default_items: [OutfitCollageLayoutItem]   // デフォルト配置 (リセット用)
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
