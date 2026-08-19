//
//  ClothingCategory.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import Foundation

enum ClothingCategory: String, CaseIterable, Identifiable {
    // コーデ解析 (v2) の item_type 5 分類と揃える。
    // クローゼットのカテゴリフィルタ・アイテム編集/登録のカテゴリ選択で共用される
    case tops = "トップス"
    case bottoms = "ボトムス"
    case outer = "アウター"
    case shoes = "シューズ"
    case accessories = "アクセサリー"

    var id: String { self.rawValue }
}
