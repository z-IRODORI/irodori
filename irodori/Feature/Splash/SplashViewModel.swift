//
//  SplashViewModel.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import Foundation
import FirebaseAuth

@MainActor
@Observable
final class SplashViewModel {
    enum State {
        case termsOfService
        case login
        case userInfo
        case home
        case onboarding
        case fashionType
        case selectStandardItem
    }
    var state: State = .termsOfService

    /// 画面の切り替え
    func updateState() {
        // 利用規約
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue) {
            state = .termsOfService
            return
        }
        // 電話番号ログイン（既存ユーザー＝userInfoあり はスキップ）
        if UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil {
            if !AuthManager.shared.isSignedIn {
                state = .login
                return
            }
        }
        // ユーザー情報設定
        if UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil {
            state = .userInfo
            return
        }
        // オンボーディング
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue) {
            state = .onboarding
            return
        }
        // ファッションタイプ診断
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue) {
            state = .fashionType
            return
        }
        // スタンダードアイテム選択
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue) {
            state = .selectStandardItem
            return
        }
        state = .home
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
        state = .login
    }
}
