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
    }
    var state: State = .termsOfService

    /// 画面の切り替え
    func updateState() {
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue) {
            state = .termsOfService
            return
        }
        if UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil {
            state = .userInfo
            return
        }
        if !UserDefaults.standard.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue) {
            state = .onboarding
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
        state = .userInfo
    }
}
