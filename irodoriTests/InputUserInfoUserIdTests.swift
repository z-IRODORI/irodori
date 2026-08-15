//
//  InputUserInfoUserIdTests.swift
//  irodoriTests
//
//  プロフィール入力確定時の userId 決定が「userId 不変」の不変条件を守ることの回帰テスト。
//  機種変更復元 (紐付け表から旧UUIDを復元) 後に Firebase UID で上書きすると
//  旧データに到達できなくなるため、既存 userId は必ず温存される。
//

import Foundation
import Testing
@testable import irodori

// UserDefaults の userId キーを共有するため直列実行 (並列だとテスト間でレースする)
@Suite(.serialized)
struct InputUserInfoUserIdTests {

    private final class SpyPrefectureClient: UpdateUserPrefectureClientProtocol {
        func put(uid: String, prefectureCode: String) async throws -> Result<UpdateUserPrefectureResponse, HTTPError> {
            .failure(.responseError)   // ネットワーク不要 (失敗しても進める仕様)
        }
    }

    @Test("既存の userId (復元済み旧UUID) は上書きされない")
    @MainActor
    func preservesRestoredLegacyUserId() async {
        let ud = UserDefaults.standard
        let legacyId = "12345678-ABCD-4EF0-9876-0123456789AB"
        ud.set(legacyId, forKey: UserDefaultsKey.userId.rawValue)
        defer { ud.removeObject(forKey: UserDefaultsKey.userId.rawValue) }

        let vm = InputUserInfoViewModel(prefectureClient: SpyPrefectureClient())
        vm.username = "テスト"
        await vm.okButtonTapped()

        #expect(ud.string(forKey: UserDefaultsKey.userId.rawValue) == legacyId)
    }

    @Test("userId が無い場合は新規発行される (空にはならない)")
    @MainActor
    func generatesUserIdWhenAbsent() async {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: UserDefaultsKey.userId.rawValue)
        defer { ud.removeObject(forKey: UserDefaultsKey.userId.rawValue) }

        let vm = InputUserInfoViewModel(prefectureClient: SpyPrefectureClient())
        vm.username = "テスト"
        await vm.okButtonTapped()

        let saved = ud.string(forKey: UserDefaultsKey.userId.rawValue)
        #expect(saved != nil && !(saved ?? "").isEmpty)
    }
}
