//
//  ReasonHeadline.swift
//  irodori
//
//  「なぜこのコーデが提案されたのか」をカードの見出し (タイポグラフィ) で伝えるための
//  フレーズ導出。バッジ/チップは使わない方針のため、色付きカプセルではなく
//  カードの題字そのものが理由を語る。
//  reason 文 (サーバ生成の自然文) はパースせず、構造化フィールドから決定論で導出する。
//  テンプレ/LLM/fallback のどの生成経路でも成立し、実挙動と矛盾する見出しが出ない。
//

import Foundation

enum ReasonHeadline {
    struct Line: Equatable {
        let text: String
        /// 挑戦枠 (テイスト圏外からの提案) のみ teal で描画し、既存の意味色を引き継ぐ
        let isDiscovery: Bool
    }

    /// 優先順位: 挑戦 > お気に入り > 手持ちで完成 > 手持ちn点 > 好み学習 > 気温。
    /// 珍しく情報量の多い理由ほど先に出す。
    /// signalCount < 10 の間は好み主張をしない (記録が少ないとテイストベクトルが
    /// ほぼ無個性になり、「あなたの好み」という見出しが実挙動と乖離するため)。
    static func line(
        for card: DailyRecommendationItem,
        signalCount: Int?,
        maxTemp: Int?,
        scopeName: String
    ) -> Line {
        if card.is_discovery {
            return .init(text: "いつもと違う、挑戦の一着", isDiscovery: true)
        }
        if card.is_favorite {
            return .init(text: "あなたが保存したコーデ", isDiscovery: false)
        }
        let owned = card.owned_items.count
        if owned > 0, card.isCloset || card.missing_items.isEmpty {
            return .init(text: "手持ちだけで、すぐ作れる", isDiscovery: false)
        }
        if owned > 0 {
            return .init(text: "手持ちの\(owned)点で組める", isDiscovery: false)
        }
        if let signalCount, signalCount >= 10 {
            return .init(text: "あなたの好みに寄せた一着", isDiscovery: false)
        }
        if let maxTemp {
            return .init(text: "最高\(maxTemp)℃の\(scopeName)向き", isDiscovery: false)
        }
        return .init(text: "\(scopeName)のおすすめ", isDiscovery: false)
    }
}
