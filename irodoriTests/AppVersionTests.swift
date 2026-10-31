//
//  AppVersionTests.swift
//  irodoriTests
//
//  強制アップデートのバージョン比較 (文字列ではなく数字で比べる)
//

import Testing
@testable import irodori

struct AppVersionTests {
    @Test("最低バージョンより古ければアップデートが必要")
    func olderRequiresUpdate() {
        #expect(AppVersion.isOlder("3.7.0", than: "3.8.0"))
        #expect(AppVersion.isOlder("3.7.9", than: "3.8"))
        #expect(AppVersion.isOlder("3.9.0", than: "3.10.0"))   // 文字列比較だと逆になる
    }

    @Test("同じか新しければ不要")
    func sameOrNewerIsFine() {
        #expect(!AppVersion.isOlder("3.8.0", than: "3.8.0"))
        #expect(!AppVersion.isOlder("3.8.1", than: "3.8.0"))
        #expect(!AppVersion.isOlder("4.0", than: "3.10.2"))
        #expect(!AppVersion.isOlder("3.7.0", than: "0.0.0"))   // 設定が無い (既定) ときは止めない
    }
}
