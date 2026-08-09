//
//  AccountLocalStateTests.swift
//  irodoriTests
//
//  新規会員登録時のローカル状態初期化が「アカウント紐付きは消す・端末スコープは残す」を守ることの回帰テスト。
//

import Foundation
import Testing
@testable import irodori

struct AccountLocalStateTests {

    @Test("アカウント紐付きキーは消え、端末スコープキーは残る")
    func resetClearsAccountKeysButKeepsDeviceKeys() {
        let ud = UserDefaults.standard

        // 端末スコープ (残るべき)
        ud.set(true, forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue)
        ud.set(true, forKey: UserDefaultsKey.notificationPromptShown.rawValue)
        // アカウント紐付き (消えるべき) の代表
        ud.set("legacy-uuid-user", forKey: UserDefaultsKey.userId.rawValue)
        ud.set(Data("dummy".utf8), forKey: UserDefaultsKey.userInfo.rawValue)
        ud.set(true, forKey: UserDefaultsKey.hasOnboarding.rawValue)
        ud.set(true, forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue)
        ud.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
        ud.set("13", forKey: UserDefaultsKey.prefectureCode.rawValue)

        AccountLocalState.resetForNewRegistration()

        #expect(ud.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue))
        #expect(ud.bool(forKey: UserDefaultsKey.notificationPromptShown.rawValue))
        #expect(ud.object(forKey: UserDefaultsKey.userId.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.hasOnboarding.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.prefectureCode.rawValue) == nil)
    }
}
