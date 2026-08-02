//
//  ClosetResponse.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/11.
//

import Foundation

struct ClosetResponse: Codable {
    let items: [ClosetItem]
}

struct ClosetItem: Codable, Identifiable, Hashable {
    let id: String
    let item_type: String
    let category: String?
    let color: String?
    let image_url: String?
    let date: String?

    /// コーデ撮影から自動で切り抜かれた画像か (Storage の items/{uid}/tops|bottoms/ 配下)。
    /// 検索追加・スタンダード追加・画像編集後の登録は items/{uid}/{item_type=日本語}/ に
    /// 保存されるため対象外になる。商品画像への差し替え導線の対象判定に使う。
    var isPhotoCropImage: Bool {
        guard let raw = image_url, !raw.isEmpty else { return false }
        let decoded = raw.removingPercentEncoding ?? raw
        guard decoded.contains("/items/") else { return false }
        return decoded.contains("/tops/") || decoded.contains("/bottoms/")
    }

    // ClothingCategoryへの変換
    var clothingCategory: ClothingCategory {
        switch item_type {
        case "トップス":
            return .tops
        case "ボトムス":
            return .bottoms
//        case "靴", "シューズ":
//            return .shoes
//        case "アウター":
//            return .outer
        default:
            return .tops // デフォルトはトップス
        }
    }
}
