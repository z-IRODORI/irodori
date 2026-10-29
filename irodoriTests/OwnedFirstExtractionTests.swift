//
//  OwnedFirstExtractionTests.swift
//  irodoriTests
//
//  ホームの3案: コーデモデルのアイテム抽出の状況を、取りに行った時点の古い控え (用意中) で巻き戻さないことの回帰テスト。
//  巻き戻すと、出ていたアイテムが「用意中」に戻って消え、ポーリングで出直す (表示・非表示を繰り返して見える)。
//

import Testing
@testable import irodori

struct OwnedFirstExtractionTests {

    private func item(_ image: String) -> OwnedFirstExtractedItem {
        OwnedFirstExtractedItem(slot: "tops", label: "シャツ", crop_url: "c.jpg", image_url: image,
                                owned_item_id: nil, owned_image_url: nil)
    }

    private func extraction(_ status: String, _ images: [String]) -> OwnedFirstExtraction {
        OwnedFirstExtraction(status: status, items: images.map(item))
    }

    @Test("初めて知る状況は取り込む")
    func acceptsFirst() {
        #expect(extraction("pending", [""]).supersedes(nil))
    }

    @Test("用意中 → 完成 は進める")
    func advancesToReady() {
        #expect(extraction("ready", ["a.png"]).supersedes(extraction("pending", [""])))
    }

    @Test("完成のあとに古い控えの用意中が来ても巻き戻さない")
    func keepsReadyAgainstStalePending() {
        #expect(!extraction("pending", [""]).supersedes(extraction("ready", ["a.png"])))
        #expect(!extraction("pending", ["a.png", ""]).supersedes(extraction("ready", ["a.png", "b.png"])))
    }

    @Test("同じ用意中でも、画像がそろった数が減る方には戻さない")
    func keepsMoreImagesWhilePending() {
        #expect(extraction("pending", ["a.png", ""]).supersedes(extraction("pending", ["", ""])))
        #expect(!extraction("pending", ["", ""]).supersedes(extraction("pending", ["a.png", ""])))
    }

    @Test("抽出前 (none) からは進める、none には戻さない")
    func noneIsLowest() {
        #expect(extraction("pending", [""]).supersedes(extraction("none", [])))
        #expect(!extraction("none", []).supersedes(extraction("pending", [""])))
    }

    @Test("同じ状況なら入れ替えない (画面を描き直さない)")
    func ignoresSame() {
        #expect(!extraction("ready", ["a.png"]).supersedes(extraction("ready", ["a.png"])))
    }
}
