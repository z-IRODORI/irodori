//
//  CoordinateRecommendResponse.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation

struct CoordinateRecommendResponse: Codable {
    let recommend_coordinates: [CoordinateRecommend]
    let outer_list: [String]?
    let tops_list: [String]?
    let bottoms_list: [String]?
    let shoes_list: [String]?
    let accessories_list: [String]?
}

struct CoordinateRecommend: Codable, Hashable {
    let coordinate_image_path: String
    let outer: ItemDetail?
    let tops: ItemDetail?
    let bottoms: ItemDetail?
    let shoes: ItemDetail?
    let accessories: ItemDetail?

    // 2x2グリッド用のアイテム情報を取得
    var gridItems: [GridItemInfo] {
        var items: [GridItemInfo] = []

        // アウター（存在する場合）
        if let outer = outer, !outer.name.isEmpty, let firstImage = outer.image_paths.first {
            items.append(GridItemInfo(
                imagePath: firstImage,
                itemName: outer.name,
                category: ItemCategory(from: outer.name)
            ))
        }

        // トップス（存在する場合）
        if let tops = tops, !tops.name.isEmpty, let firstImage = tops.image_paths.first {
            items.append(GridItemInfo(
                imagePath: firstImage,
                itemName: tops.name,
                category: ItemCategory(from: tops.name)
            ))
        }

        // ボトムス（存在する場合）
        if let bottoms = bottoms, !bottoms.name.isEmpty, let firstImage = bottoms.image_paths.first {
            items.append(GridItemInfo(
                imagePath: firstImage,
                itemName: bottoms.name,
                category: ItemCategory(from: bottoms.name)
            ))
        }

        // シューズ（存在する場合）
        if let shoes = shoes, !shoes.name.isEmpty, let firstImage = shoes.image_paths.first {
            items.append(GridItemInfo(
                imagePath: firstImage,
                itemName: shoes.name,
                category: ItemCategory(from: shoes.name)
            ))
        }

        // アクセサリー（存在する場合）
        if let accessories = accessories, !accessories.name.isEmpty, let firstImage = accessories.image_paths.first {
            items.append(GridItemInfo(
                imagePath: firstImage,
                itemName: accessories.name,
                category: ItemCategory(from: accessories.name)
            ))
        }

        // 4枚に満たない場合は空のアイテムで埋める
        while items.count < 4 {
            items.append(GridItemInfo(imagePath: "", itemName: "", category: .unknown))
        }

        return Array(items.prefix(4))
    }
}

// 2x2グリッド用のアイテム情報
struct GridItemInfo: Hashable, Equatable {
    let imagePath: String
    let itemName: String
    let category: ItemCategory

    var iconName: String {
        return category.iconName
    }
}

struct ItemDetail: Codable, Hashable {
    let name: String
    let image_paths: [String]
}

extension CoordinateRecommendResponse {
    static func mock() -> CoordinateRecommendResponse {
        return CoordinateRecommendResponse(
            recommend_coordinates: [
                CoordinateRecommend(
                    coordinate_image_path: "coordinates/google/071248eb61c5083d4537f4e973652b0d.png",
                    outer: nil,
                    tops: ItemDetail(
                        name: "トップス_パーカー_グレー",
                        image_paths: [
                            "items/トップス_パーカー_グレー/00.png",
                            "items/トップス_パーカー_グレー/01.png",
                            "items/トップス_パーカー_グレー/02.png",
                            "items/トップス_パーカー_グレー/03.png",
                            "items/トップス_パーカー_グレー/04.png"
                        ]
                    ),
                    bottoms: nil,
                    shoes: ItemDetail(
                        name: "シューズ_サンダル_ブラック",
                        image_paths: [
                            "items/シューズ_サンダル_ブラック/00.png",
                            "items/シューズ_サンダル_ブラック/01.png",
                            "items/シューズ_サンダル_ブラック/02.png",
                            "items/シューズ_サンダル_ブラック/03.png",
                            "items/シューズ_サンダル_ブラック/04.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "アクセサリー_ネックレス_ゴールド",
                        image_paths: [
                            "items/アクセサリー_ネックレス_ゴールド/00.png",
                            "items/アクセサリー_ネックレス_ゴールド/01.png",
                            "items/アクセサリー_ネックレス_ゴールド/02.png",
                            "items/アクセサリー_ネックレス_ゴールド/03.png",
                            "items/アクセサリー_ネックレス_ゴールド/04.png"
                        ]
                    )
                ),
                CoordinateRecommend(
                    coordinate_image_path: "coordinates/google/146099eb0a01e021db9853286b9e5825.png",
                    outer: ItemDetail(
                        name: "アウター_ミリタリーコート_カーキ",
                        image_paths: [
                            "items/アウター_ミリタリーコート_カーキ/00.png",
                            "items/アウター_ミリタリーコート_カーキ/01.png",
                            "items/アウター_ミリタリーコート_カーキ/02.png",
                            "items/アウター_ミリタリーコート_カーキ/03.png",
                            "items/アウター_ミリタリーコート_カーキ/04.png"
                        ]
                    ),
                    tops: ItemDetail(
                        name: "トップス_Tシャツ_ホワイト",
                        image_paths: [
                            "items/トップス_Tシャツ_ホワイト/00.png",
                            "items/トップス_Tシャツ_ホワイト/01.png",
                            "items/トップス_Tシャツ_ホワイト/02.png",
                            "items/トップス_Tシャツ_ホワイト/03.png",
                            "items/トップス_Tシャツ_ホワイト/04.png"
                        ]
                    ),
                    bottoms: nil,
                    shoes: ItemDetail(
                        name: "シューズ_厚底シューズ_ブラック",
                        image_paths: [
                            "items/シューズ_厚底シューズ_ブラック/00.png",
                            "items/シューズ_厚底シューズ_ブラック/01.png",
                            "items/シューズ_厚底シューズ_ブラック/02.png",
                            "items/シューズ_厚底シューズ_ブラック/03.png",
                            "items/シューズ_厚底シューズ_ブラック/04.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "アクセサリー_サングラス_ベージュ",
                        image_paths: [
                            "items/アクセサリー_サングラス_ベージュ/00.png",
                            "items/アクセサリー_サングラス_ベージュ/01.png",
                            "items/アクセサリー_サングラス_ベージュ/02.png",
                            "items/アクセサリー_サングラス_ベージュ/03.png",
                            "items/アクセサリー_サングラス_ベージュ/04.png"
                        ]
                    )
                ),
                CoordinateRecommend(
                    coordinate_image_path: "coordinates/google/14bccd39640e64629b4d9bf32d20874a.png",
                    outer: nil,
                    tops: ItemDetail(
                        name: "トップス_セーター_レッド",
                        image_paths: [
                            "items/トップス_セーター_レッド/00.png",
                            "items/トップス_セーター_レッド/01.png",
                            "items/トップス_セーター_レッド/02.png",
                            "items/トップス_セーター_レッド/03.png",
                            "items/トップス_セーター_レッド/04.png"
                        ]
                    ),
                    bottoms: nil,
                    shoes: ItemDetail(
                        name: "シューズ_サンダル_ホワイト",
                        image_paths: [
                            "items/シューズ_サンダル_ホワイト/00.png",
                            "items/シューズ_サンダル_ホワイト/01.png",
                            "items/シューズ_サンダル_ホワイト/02.png",
                            "items/シューズ_サンダル_ホワイト/03.png",
                            "items/シューズ_サンダル_ホワイト/04.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "アクセサリー_ハンドバッグ_ブラウン",
                        image_paths: [
                            "items/アクセサリー_ハンドバッグ_ブラウン/00.png",
                            "items/アクセサリー_ハンドバッグ_ブラウン/01.png",
                            "items/アクセサリー_ハンドバッグ_ブラウン/02.png",
                            "items/アクセサリー_ハンドバッグ_ブラウン/03.png",
                            "items/アクセサリー_ハンドバッグ_ブラウン/04.png"
                        ]
                    )
                )
            ],
            outer_list: [
                "アウター_パーカー_ネイビー",
                "アウター_ミリタリーコート_カーキ",
                "アウター_ベスト_ネイビー",
                "アウター_コート_キャメル",
                "アウター_ダウンジャケット_オフホワイト"
            ],
            tops_list: [
                "トップス_Tシャツ_ホワイト",
                "トップス_スウェット_ブラック",
                "トップス_Tシャツ_ライトベージュ",
                "トップス_パーカー_ライトグレー",
                "トップス_セーター_レッド"
            ],
            bottoms_list: [
                "ボトムス_ワイドパンツ_ブラック",
                "ボトムス_スウェットパンツ_ライトグレー",
                "ボトムス_ワイドパンツ_ダークグレー",
                "ボトムス_パンツ_レッド",
                "ボトムス_ジーンズ_ブルー"
            ],
            shoes_list: [
                "シューズ_ローファー_ブラック",
                "シューズ_サンダル_ブラック",
                "シューズ_厚底シューズ_ブラック",
                "シューズ_スニーカー_ブラック",
                "シューズ_サンダル_ホワイト"
            ],
            accessories_list: [
                "アクセサリー_メガネ_ブラック",
                "アクセサリー_ネックレス_シルバー",
                "アクセサリー_キーホルダー_マルチカラー",
                "アクセサリー_腕時計_シルバー",
                "アクセサリー_ハンドバッグ_ブラック"
            ]
        )
    }
}
