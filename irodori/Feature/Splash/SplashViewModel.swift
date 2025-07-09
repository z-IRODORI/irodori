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
        state = .home
    }
}
