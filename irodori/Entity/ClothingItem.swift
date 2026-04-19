//
//  ClothingItem.swift
//  irodori
//
//  Created by yuki.hamada on 2026/01/04.
//

import Foundation
import SwiftUI

struct ClothingItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: ClothingCategory // String ではなく enum を使用
    let image: ImageResource
}
