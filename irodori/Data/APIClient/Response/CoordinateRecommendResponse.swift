//
//  CoordinateRecommendResponse.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation

struct CoordinateRecommendResponse: Codable {
    let recommend_coordinates: [CoordinateRecommend]
    let outer_list: [String]
    let bottoms_list: [String]
    let shoes_list: [String]
    let accessories_list: [String]
}

struct CoordinateRecommend: Codable, Hashable {
    let coordinate_image: String
    let outer: ItemDetail
    let bottoms: ItemDetail
    let shoes: ItemDetail
    let accessories: ItemDetail

    // 画像パスを取得（2x2グリッド用に4枚取得）
    var imagePaths: [String] {
        var paths: [String] = []

        // outer, bottoms, shoes, accessories の順で画像を追加
        // 各アイテムから最初の画像を取得（存在する場合）
        if let firstOuterImage = outer.image_paths.first, !outer.name.isEmpty {
            paths.append(firstOuterImage)
        }
        if let firstBottomsImage = bottoms.image_paths.first {
            paths.append(firstBottomsImage)
        }
        if let firstShoesImage = shoes.image_paths.first {
            paths.append(firstShoesImage)
        }
        if let firstAccessoryImage = accessories.image_paths.first {
            paths.append(firstAccessoryImage)
        }

        // 4枚に満たない場合は空文字で埋める（表示側でプレースホルダー表示）
        while paths.count < 4 {
            paths.append("")
        }

        return Array(paths.prefix(4))
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
                    coordinate_image: "071248eb61c5083d4537f4e973652b0d",
                    outer: ItemDetail(name: "", image_paths: []),
                    bottoms: ItemDetail(
                        name: "ワイドパンツ",
                        image_paths: [
                            "items/ワイドパンツ/00.png",
                            "items/ワイドパンツ/01.png",
                            "items/ワイドパンツ/02.png"
                        ]
                    ),
                    shoes: ItemDetail(
                        name: "サンダル",
                        image_paths: [
                            "items/サンダル/00.png",
                            "items/サンダル/01.png",
                            "items/サンダル/02.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "ネックレス",
                        image_paths: [
                            "items/ネックレス/00.png",
                            "items/ネックレス/01.png",
                            "items/ネックレス/02.png"
                        ]
                    )
                ),
                CoordinateRecommend(
                    coordinate_image: "146099eb0a01e021db9853286b9e5825",
                    outer: ItemDetail(
                        name: "ミリタリーコート",
                        image_paths: [
                            "items/ミリタリーコート/00.png",
                            "items/ミリタリーコート/01.png",
                            "items/ミリタリーコート/02.png"
                        ]
                    ),
                    bottoms: ItemDetail(
                        name: "ワイドパンツ",
                        image_paths: [
                            "items/ワイドパンツ/00.png",
                            "items/ワイドパンツ/01.png",
                            "items/ワイドパンツ/02.png"
                        ]
                    ),
                    shoes: ItemDetail(
                        name: "厚底シューズ",
                        image_paths: [
                            "items/厚底シューズ/00.png",
                            "items/厚底シューズ/01.png",
                            "items/厚底シューズ/02.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "サングラス",
                        image_paths: [
                            "items/サングラス/00.png",
                            "items/サングラス/01.png",
                            "items/サングラス/02.png"
                        ]
                    )
                ),
                CoordinateRecommend(
                    coordinate_image: "14bccd39640e64629b4d9bf32d20874a",
                    outer: ItemDetail(name: "", image_paths: []),
                    bottoms: ItemDetail(
                        name: "ジーンズ",
                        image_paths: [
                            "items/ジーンズ/00.png",
                            "items/ジーンズ/01.png",
                            "items/ジーンズ/02.png"
                        ]
                    ),
                    shoes: ItemDetail(
                        name: "サンダル",
                        image_paths: [
                            "items/サンダル/00.png",
                            "items/サンダル/01.png",
                            "items/サンダル/02.png"
                        ]
                    ),
                    accessories: ItemDetail(
                        name: "ハンドバッグ",
                        image_paths: [
                            "items/ハンドバッグ/00.png",
                            "items/ハンドバッグ/01.png",
                            "items/ハンドバッグ/02.png"
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
