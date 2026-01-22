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
    let outer: String
    let bottoms: String
    let shoes: String
    let accessories: String
}

extension CoordinateRecommendResponse {
    static func mock() -> CoordinateRecommendResponse {
        return CoordinateRecommendResponse(
            recommend_coordinates: [
                CoordinateRecommend(
                    coordinate_image: "071248eb61c5083d4537f4e973652b0d",
                    outer: "",
                    bottoms: "ボトムス_ワイドパンツ_ブラック",
                    shoes: "シューズ_サンダル_ブラック",
                    accessories: "アクセサリー_ネックレス_ゴールド アクセサリー_メガネ_ブラック アクセサリー_腕時計_シルバー"
                ),
                CoordinateRecommend(
                    coordinate_image: "146099eb0a01e021db9853286b9e5825",
                    outer: "アウター_ミリタリーコート_カーキ",
                    bottoms: "ボトムス_ワイドパンツ_ブラック",
                    shoes: "シューズ_厚底シューズ_ブラック",
                    accessories: "アクセサリー_サングラス_ベージュ アクセサリー_サングラス_イエロー アクセサリー_ショルダーバッグ_シルバー"
                ),
                CoordinateRecommend(
                    coordinate_image: "14bccd39640e64629b4d9bf32d20874a",
                    outer: "",
                    bottoms: "ボトムス_ジーンズ_ブルー",
                    shoes: "シューズ_サンダル_ホワイト",
                    accessories: "アクセサリー_ハンドバッグ_ブラウン アクセサリー_メガネ_ゴールド アクセサリー_ネックレス_ホワイト"
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
