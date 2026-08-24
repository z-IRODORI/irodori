//
//  TryOnSourceMapping.swift
//  irodori
//
//  既存レスポンス型 → TryOnSource の変換。
//  試着ボタンの表示可否 (nil = 非表示) もここで一元判定する。
//

import Foundation

extension OutfitCollageResponse {
    /// クローゼットのコーデ提案 → closet モード。
    /// 着衣スロット優先で最大 6 点。2 点未満は試着不可 (nil = ボタン非表示)。
    var tryOnSource: TryOnSource? {
        let slotPriority = ["tops", "bottoms", "outer", "shoes", "bag", "accessory"]
        let usable = items
            .filter { !$0.image_url.isEmpty }
            .sorted {
                (slotPriority.firstIndex(of: $0.slot) ?? slotPriority.count)
                    < (slotPriority.firstIndex(of: $1.slot) ?? slotPriority.count)
            }
            .prefix(TryOnSource.maxClosetItems)
            .map {
                TryOnClosetItem(
                    id: $0.id,
                    slot: $0.slot,
                    label: "\($0.slotDisplayName): \($0.displayName)",
                    imageURL: $0.image_url)
            }
        guard usable.count >= TryOnSource.minClosetItems else { return nil }
        return .closet(items: Array(usable))
    }
}

extension DailyRecommendationItem {
    /// おすすめコーデ → 試着ソース。
    /// - kind = pool / self: スナップ写真をそのまま参照する snap モード
    /// - kind = closet: image_url はコラージュ画像で試着参照に不適なため、
    ///   クローゼット実物写真 (owned_items) で closet モード
    var tryOnSource: TryOnSource? {
        if isCloset {
            let closetItems = owned_items
                .filter { !$0.image_url.isEmpty }
                .prefix(TryOnSource.maxClosetItems)
                .map {
                    TryOnClosetItem(
                        id: $0.item_id,
                        slot: $0.slot,
                        label: "\(Self.slotDisplayName($0.slot)): \($0.label)",
                        imageURL: $0.image_url)
                }
            guard closetItems.count >= TryOnSource.minClosetItems else { return nil }
            return .closet(items: Array(closetItems))
        }
        guard !image_url.isEmpty else { return nil }
        let labels = items.compactMap { slot, name -> String? in
            guard let name, !name.isEmpty else { return nil }
            return "\(Self.slotDisplayName(slot)): \(name)"
        }
        return .snap(id: id, imageURL: image_url, labels: labels)
    }

    private static func slotDisplayName(_ slot: String) -> String {
        switch slot {
        case "tops": return "トップス"
        case "bottoms": return "ボトムス"
        case "outer": return "アウター"
        case "shoes": return "シューズ"
        case "bag": return "バッグ"
        case "accessory": return "小物"
        default: return slot
        }
    }
}
