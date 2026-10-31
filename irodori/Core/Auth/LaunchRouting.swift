//
//  LaunchRouting.swift
//  irodori
//
//  起動時にどの画面を出すかと、ログイン直後に端末をどう整えるかの「決まり」だけを書く (テストできる純粋な関数)。
//  SplashViewModel・AccountResolver・FreshInstallGuard はここを呼ぶだけにする。
//
//  起動時の画面:
//    利用規約に未同意 → 利用規約
//    ログインしていない → 「新規会員登録 / ログイン」を選ぶ画面
//    プロフィールが無い → プロフィール入力
//    相棒がいない → 4つの質問 (オンボーディング)
//    それ以外 → ホーム
//

import Foundation

enum LaunchScreen: Equatable {
    case termsOfService, login, userInfo, onboarding, home
}

struct LaunchFacts: Equatable {
    var agreedToTerms: Bool
    var signedIn: Bool
    var hasUserInfo: Bool
    var finishedOnboarding: Bool
}

enum LaunchRouting {
    static func screen(for f: LaunchFacts) -> LaunchScreen {
        if !f.agreedToTerms { return .termsOfService }
        if !f.signedIn { return .login }
        if !f.hasUserInfo { return .userInfo }
        if !f.finishedOnboarding { return .onboarding }
        return .home
    }

    /// アプリを消して入れ直した直後か。
    /// アプリを消すと UserDefaults は消えるが、Firebase のログインはキーチェーンに残る。
    /// 「入れ直したのにログイン済みのまま入力画面に飛ぶ」のを防ぐため、このときはログインを外す。
    /// アップデートでは UserDefaults が残る (利用規約に同意済み) ので、既存ユーザーはログアウトしない。
    static func isFreshInstall(agreedToTerms: Bool, launchedBefore: Bool) -> Bool {
        !agreedToTerms && !launchedBefore
    }

    // MARK: ログイン直後

    enum Intent: Equatable { case register, login }

    /// 選んだ入口と、サーバが知っていた実際のアカウントが食い違ったときに知らせること
    enum Notice: Equatable {
        /// 新規会員登録を選んだが、この電話番号はもう登録されていた → そのアカウントでログインした
        case alreadyRegistered
        /// ログインを選んだが、この電話番号はまだ登録されていなかった → 新規登録として始める
        case notRegisteredYet
    }

    struct Plan: Equatable {
        /// 端末に残っている別の人のアカウント状態を消す
        var resetLocal: Bool
        var notice: Notice?
    }

    static func plan(localUserId: String?, resolvedUserId: String, isNewAccount: Bool, intent: Intent?) -> Plan {
        let local = localUserId ?? ""
        let reset = !local.isEmpty && local != resolvedUserId
        var notice: Notice?
        switch intent {
        case .register? where !isNewAccount: notice = .alreadyRegistered
        case .login? where isNewAccount: notice = .notRegisteredYet
        default: notice = nil
        }
        return Plan(resetLocal: reset, notice: notice)
    }

    // MARK: 途中でやめた登録・ログイン

    enum Restart: Equatable {
        case none
        /// 最初 (スプラッシュ) からやり直す。clearLocalAccount: 今回の登録で端末に作った状態も消す
        case startOver(clearLocalAccount: Bool)
    }

    /// 起動時に1回: 「新規会員登録 / ログイン」を始めたのにホームまで行かずにアプリを終えていたら、最初からやり直す。
    /// 登録を始める前から端末にアカウントがあった人 (電話番号認証の前から使っている人) は、端末のデータを消さない。
    static func restart(registrationInProgress: Bool, screen: LaunchScreen, hadLocalAccountBefore: Bool) -> Restart {
        guard registrationInProgress, screen != .home else { return .none }
        return .startOver(clearLocalAccount: !hadLocalAccountBefore)
    }
}

/// 「新規会員登録 / ログイン」の途中かどうかの記録 (端末にだけ持つ)
@MainActor
enum RegistrationProgress {
    private static let inProgressKey = "registration.inProgress"
    private static let hadLocalAccountKey = "registration.hadLocalAccount"

    static var isInProgress: Bool { UserDefaults.standard.bool(forKey: inProgressKey) }
    static var hadLocalAccountBefore: Bool { UserDefaults.standard.bool(forKey: hadLocalAccountKey) }

    /// スプラッシュの「次へ」、「新規会員登録」「ログイン」を押したとき
    static func begin() {
        let d = UserDefaults.standard
        if !d.bool(forKey: inProgressKey) {
            let hadAccount = !(d.string(forKey: UserDefaultsKey.userId.rawValue) ?? "").isEmpty
                || d.object(forKey: UserDefaultsKey.userInfo.rawValue) != nil
            d.set(hadAccount, forKey: hadLocalAccountKey)
        }
        d.set(true, forKey: inProgressKey)
    }

    /// ホームまで来た (登録・ログインが最後まで終わった)
    static func finish() {
        UserDefaults.standard.removeObject(forKey: inProgressKey)
        UserDefaults.standard.removeObject(forKey: hadLocalAccountKey)
    }
}
