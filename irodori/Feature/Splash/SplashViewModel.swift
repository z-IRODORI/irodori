//
//  SplashViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import Foundation

@MainActor
@Observable
final class SplashViewModel {
    enum State {
        case termsOfService
        case userInfo
        case home
        case onboarding
        case fashionType
        case selectStandardItem
        case firstTakePhoto
    }
    var state: State = .termsOfService

    /// 画面の切り替え
    func updateState() {
        print("🔍 [SplashViewModel] updateState called")
        print("   - hasAgreedToTermsOfService: \(UserDefaults.standard.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue))")
        print("   - userInfo: \(UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) != nil)")
        print("   - hasOnboarding: \(UserDefaults.standard.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue))")
        print("   - hasFashionTypeDiagnosis: \(UserDefaults.standard.bool(forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue))")
        print("   - hasSelectedStandardItems: \(UserDefaults.standard.bool(forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue))")
        print("   - finishedFirstTakePhoto: \(UserDefaults.standard.bool(forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue))")

        // 利用規約
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue) {
            state = .termsOfService
            print("   → state = .termsOfService")
            return
        }
        // ユーザー情報設定
        if UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil {
            state = .userInfo
            print("   → state = .userInfo")
            return
        }
        // オンボーディング
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue) {
            state = .onboarding
            print("   → state = .onboarding")
            return
        }
        // ファッションタイプ診断
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue) {
            state = .fashionType
            print("   → state = .fashionType")
            return
        }
        // スタンダードアイテム選択
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue) {
            state = .selectStandardItem
            print("   → state = .selectStandardItem")
            return
        }
        // 初回撮影画面
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.finishedFirstTakePhoto.rawValue) {
            state = .firstTakePhoto
            print("   → state = .firstTakePhoto")
            return
        }
        state = .home
        print("   → state = .home")
    }

    func setupSignUpDate() {
        let repository = SignUpDateRepository()
        repository.saveNow()
    }

    func viewedOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasOnboarding.rawValue)
    }

    func nextButtonTapped() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue)
        state = .userInfo
    }
}
