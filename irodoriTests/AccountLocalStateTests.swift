//
//  AccountLocalStateTests.swift
//  irodoriTests
//
//  新規会員登録時のローカル状態初期化が「アカウント紐付きは消す・端末スコープは残す」を守ることの回帰テスト。
//

import Foundation
import Testing
@testable import irodori

@MainActor
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

    @Test("控えの消去: 相棒・3案・ホームの控えは消え、プロフィール・userId・誕生済みの印は残る")
    func clearServerMirrorsKeepsAccount() {
        let ud = UserDefaults.standard
        ud.set("uid-1", forKey: UserDefaultsKey.userId.rawValue)
        ud.set(Data("dummy".utf8), forKey: UserDefaultsKey.userInfo.rawValue)
        ud.set(true, forKey: UserDefaultsKey.hasOnboarding.rawValue)
        ud.set("トレンド・エディター", forKey: UserDefaultsKey.partnerImage.rawValue)
        ud.set("トレンド・エディター_icon", forKey: UserDefaultsKey.partnerIconImage.rawValue)
        ud.set(Data("old".utf8), forKey: UserDefaultsKey.partnerOnboardingResponse.rawValue)
        ud.set(Data("old".utf8), forKey: "renewalHome.savedResponse")
        ud.set(Data("old".utf8), forKey: "homeSectionCache_home_uid-1")

        AccountLocalState.clearServerMirrors()

        #expect(ud.string(forKey: UserDefaultsKey.userId.rawValue) == "uid-1")
        #expect(ud.object(forKey: UserDefaultsKey.userInfo.rawValue) != nil)
        #expect(ud.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))
        #expect(ud.object(forKey: UserDefaultsKey.partnerImage.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.partnerIconImage.rawValue) == nil)
        #expect(ud.object(forKey: UserDefaultsKey.partnerOnboardingResponse.rawValue) == nil)
        #expect(ud.object(forKey: "renewalHome.savedResponse") == nil)
        #expect(ud.object(forKey: "homeSectionCache_home_uid-1") == nil)
    }

    @Test("相棒の写し: サーバのタイプ名を写す。絵の無いタイプ名は写さない")
    func partnerMirrorAppliesOnlyKnownTypes() {
        let ud = UserDefaults.standard
        PartnerLocalMirror.apply(typeName: "エッセンシャル・ワーカー")
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == "エッセンシャル・ワーカー")
        #expect(ud.string(forKey: UserDefaultsKey.partnerIconImage.rawValue) == "エッセンシャル・ワーカー_icon")
        PartnerLocalMirror.apply(typeName: "存在しないタイプ")
        #expect(ud.string(forKey: UserDefaultsKey.partnerImage.rawValue) == "エッセンシャル・ワーカー")
    }
}
