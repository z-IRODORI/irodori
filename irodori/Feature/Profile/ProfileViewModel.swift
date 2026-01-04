//
//  ProfileViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    var selectedCategory: ClothingCategory = .all

    // データリスト
    private let allItems: [ClothingItem] = [
        .init(name: "ダウン", category: .outer, image: .item1),
        .init(name: "白T", category: .tops, image: .item2),
        .init(name: "赤T", category: .tops, image: .item3),
        .init(name: "緑T", category: .tops, image: .item4),
        .init(name: "スウェット", category: .tops, image: .item5),
        .init(name: "青シャツ", category: .tops, image: .item1),
        .init(name: "キャップ", category: .outer, image: .item3),
        .init(name: "スニーカー", category: .shoes, image: .item4),
    ]

    // フィルタリング済みアイテム
    var filteredItems: [ClothingItem] {
        if selectedCategory == .all {
            return allItems
        }
        return allItems.filter { $0.category == selectedCategory }
    }
}
