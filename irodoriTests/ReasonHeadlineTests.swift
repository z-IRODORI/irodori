//
//  ReasonHeadlineTests.swift
//  irodoriTests
//
//  カード題字 (決め手フレーズ) の導出が優先順位と正直さガードを守ることの回帰テスト。
//  嘘見出し禁止: 実データ (構造化フィールド) が裏付けない主張をしないこと。
//

import Foundation
import Testing
@testable import irodori

struct ReasonHeadlineTests {

    private func makeCard(
        kind: String = "pool",
        isDiscovery: Bool = false,
        isFavorite: Bool = false,
        ownedCount: Int = 0,
        missingItems: [String] = []
    ) -> DailyRecommendationItem {
        let owned = (0..<ownedCount).map {
            DailyOwnedItem(slot: "tops", item_id: "i\($0)", image_url: "", label: "アイテム\($0)")
        }
        return DailyRecommendationItem(
            pool_id: "p1",
            kind: kind,
            image_url: "",
            reason: nil,
            main_colors: [],
            items: [:],
            vibe: "",
            style: "casual",
            cleanliness: 3,
            is_favorite: isFavorite,
            is_discovery: isDiscovery,
            owned_items: owned,
            missing_items: missingItems
        )
    }

    @Test("挑戦枠が最優先で、tealフラグが立つ")
    func discoveryWinsOverEverything() {
        let card = makeCard(isDiscovery: true, isFavorite: true, ownedCount: 2)
        let line = ReasonHeadline.line(for: card, signalCount: 42, maxTemp: 28, scopeName: "明日")
        #expect(line == .init(text: "いつもと違う、挑戦の一着", isDiscovery: true))
    }

    @Test("お気に入りは手持ちより優先")
    func favoriteBeatsCloset() {
        let card = makeCard(isFavorite: true, ownedCount: 2)
        let line = ReasonHeadline.line(for: card, signalCount: 42, maxTemp: 28, scopeName: "明日")
        #expect(line.text == "あなたが保存したコーデ")
        #expect(!line.isDiscovery)
    }

    @Test("手持ちで完成 (missingなし) と手持ちn点の使い分け")
    func closetPhrases() {
        let complete = makeCard(ownedCount: 2, missingItems: [])
        #expect(ReasonHeadline.line(for: complete, signalCount: nil, maxTemp: nil, scopeName: "今日").text
                == "手持ちだけで、すぐ作れる")

        let partial = makeCard(ownedCount: 2, missingItems: ["黒 スラックス"])
        #expect(ReasonHeadline.line(for: partial, signalCount: nil, maxTemp: nil, scopeName: "今日").text
                == "手持ちの2点で組める")

        let closetKind = makeCard(kind: "closet", ownedCount: 3)
        #expect(ReasonHeadline.line(for: closetKind, signalCount: nil, maxTemp: nil, scopeName: "今日").text
                == "手持ちだけで、すぐ作れる")
    }

    @Test("記録10回未満では好み主張をしない (嘘見出し禁止)")
    func tasteClaimRequiresSignals() {
        let card = makeCard()
        // 記録が十分 → 好み見出し
        #expect(ReasonHeadline.line(for: card, signalCount: 10, maxTemp: 28, scopeName: "明日").text
                == "あなたの好みに寄せた一着")
        // 記録不足 → 気温フォールバック (全カードが気温フィルタ通過済みなので常に正直)
        #expect(ReasonHeadline.line(for: card, signalCount: 9, maxTemp: 28, scopeName: "明日").text
                == "最高28℃の明日向き")
        // 記録なし扱い (nil) も同様
        #expect(ReasonHeadline.line(for: card, signalCount: nil, maxTemp: 30, scopeName: "週末").text
                == "最高30℃の週末向き")
    }

    @Test("気温もない場合の最終フォールバック")
    func lastResortFallback() {
        let card = makeCard()
        #expect(ReasonHeadline.line(for: card, signalCount: nil, maxTemp: nil, scopeName: "明日").text
                == "明日のおすすめ")
    }

    @Test("手持ち0のclosetは手持ち見出しにしない")
    func emptyClosetKindDoesNotClaimCloset() {
        let card = makeCard(kind: "closet", ownedCount: 0)
        let line = ReasonHeadline.line(for: card, signalCount: nil, maxTemp: 25, scopeName: "今日")
        #expect(line.text == "最高25℃の今日向き")
    }
}
