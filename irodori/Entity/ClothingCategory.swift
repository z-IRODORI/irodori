//
//  ClothingCategory.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import Foundation

enum ClothingCategory: String, CaseIterable, Identifiable {
    case all = "全て"
    case tops = "トップス"
    case bottoms = "ボトムス"
    case shoes = "靴"
    case outer = "アウター"

    var id: String { self.rawValue }
}
