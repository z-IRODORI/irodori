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

    private static let launchedBeforeKey = "app.launchedBefore"

    /// 起動時に1回: アプリを入れ直した直後なら、キーチェーンに残った Firebase のログインを外す
    func signOutLeftoverSessionIfFreshInstall() {
        let d = UserDefaults.standard
        let agreed = d.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue)
        let before = d.bool(forKey: Self.launchedBeforeKey)
        if LaunchRouting.isFreshInstall(agreedToTerms: agreed, launchedBefore: before) {
            try? Auth.auth().signOut()
        }
        d.set(true, forKey: Self.launchedBeforeKey)
    }

    /// 起動時に1回: 登録・ログインを途中でやめていたら、ログインを外してスプラッシュ (利用規約) からやり直す
    func startOverIfRegistrationAbandoned() {
        let decision = LaunchRouting.restart(
            registrationInProgress: RegistrationProgress.isInProgress,
            screen: currentScreen(),
            hadLocalAccountBefore: RegistrationProgress.hadLocalAccountBefore
        )
        guard case .startOver(let clearLocal) = decision else { return }
        try? Auth.auth().signOut()
        if clearLocal {
            AccountLocalState.resetForNewRegistration()
        }
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue)
        RegistrationProgress.finish()
    }

    /// 画面の切り替え (決まりは LaunchRouting)
    func updateState() {
        switch currentScreen() {
        case .termsOfService: state = .termsOfService
        case .login: state = .login
        case .userInfo: state = .userInfo
        case .onboarding: state = .onboarding
        case .home:
            state = .home
            RegistrationProgress.finish()
        }
    }

    private func currentScreen() -> LaunchScreen {
        let d = UserDefaults.standard
        let facts = LaunchFacts(
            agreedToTerms: d.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue),
            signedIn: AuthManager.shared.isSignedIn,
            hasUserInfo: d.object(forKey: UserDefaultsKey.userInfo.rawValue) != nil,
            finishedOnboarding: d.bool(forKey: UserDefaultsKey.hasOnboarding.rawValue)
                && d.bool(forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue)
                && d.bool(forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
        )
        return LaunchRouting.screen(for: facts)
    }

    func setupSignUpDate() {
        let repository = SignUpDateRepository()
        repository.saveNow()
    }

    func viewedOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasOnboarding.rawValue)
    }

    func nextButtonTapped() {
        RegistrationProgress.begin()
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue)
        // 直接 .login にセットしない: 再インストールでキーチェーンに Firebase セッションが
        // 残っている場合はログインをスキップして次のステップへ進めるため、ルーティングに任せる
        updateState()
    }
}
