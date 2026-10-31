//
//  LaunchRoutingTests.swift
//  irodoriTests
//
//  起動時の画面とログイン直後の整え方の決まり (LaunchRouting) のテスト。
//  「ログインしていないのにプロフィール入力が出る」「選び方で別アカウントになる」を防ぐ。
//

import Testing
@testable import irodori

struct LaunchRoutingTests {

    private func facts(terms: Bool = true, signedIn: Bool = true, userInfo: Bool = true, onboarding: Bool = true) -> LaunchFacts {
        LaunchFacts(agreedToTerms: terms, signedIn: signedIn, hasUserInfo: userInfo, finishedOnboarding: onboarding)
    }

    // MARK: 起動時の画面

    @Test("初めて起動: 利用規約から")
    func firstLaunchShowsTerms() {
        #expect(LaunchRouting.screen(for: facts(terms: false, signedIn: false, userInfo: false, onboarding: false)) == .termsOfService)
    }

    @Test("利用規約に同意済みでログインしていない: 新規会員登録 / ログインの画面 (プロフィール入力には行かない)")
    func notSignedInShowsLogin() {
        #expect(LaunchRouting.screen(for: facts(signedIn: false, userInfo: false, onboarding: false)) == .login)
        // 端末に前のプロフィールが残っていても、ログインしていなければログイン画面
        #expect(LaunchRouting.screen(for: facts(signedIn: false, userInfo: true, onboarding: true)) == .login)
    }

    @Test("ログイン済みでプロフィールが無い: プロフィール入力")
    func signedInWithoutProfile() {
        #expect(LaunchRouting.screen(for: facts(userInfo: false, onboarding: false)) == .userInfo)
    }

    @Test("ログイン済みでプロフィールはあるが相棒がいない: 4つの質問")
    func signedInWithoutPartner() {
        #expect(LaunchRouting.screen(for: facts(onboarding: false)) == .onboarding)
    }

    @Test("すべてそろっている: ホーム")
    func allDoneShowsHome() {
        #expect(LaunchRouting.screen(for: facts()) == .home)
    }

    // MARK: 入れ直し (キーチェーンに Firebase のログインが残る)

    @Test("アプリを入れ直した直後: 残ったログインを外す")
    func freshInstallSignsOut() {
        #expect(LaunchRouting.isFreshInstall(agreedToTerms: false, launchedBefore: false))
    }

    @Test("アップデート・2回目以降の起動: ログインを外さない")
    func updateKeepsSession() {
        // アップデート直後 (利用規約に同意済みで、起動記録はまだ無い既存ユーザー)
        #expect(!LaunchRouting.isFreshInstall(agreedToTerms: true, launchedBefore: false))
        // 2回目以降の起動
        #expect(!LaunchRouting.isFreshInstall(agreedToTerms: false, launchedBefore: true))
        #expect(!LaunchRouting.isFreshInstall(agreedToTerms: true, launchedBefore: true))
    }

    // MARK: ログイン直後

    @Test("同じ人が同じ端末でログイン: 端末の状態はそのまま")
    func sameUserKeepsLocal() {
        let p = LaunchRouting.plan(localUserId: "u1", resolvedUserId: "u1", isNewAccount: false, intent: .login)
        #expect(p == .init(resetLocal: false, notice: nil))
    }

    @Test("別の人が同じ端末でログイン: 前の人の状態を消す")
    func otherUserResetsLocal() {
        let p = LaunchRouting.plan(localUserId: "u1", resolvedUserId: "u2", isNewAccount: false, intent: .login)
        #expect(p.resetLocal)
    }

    @Test("新しい端末でログイン (端末に何も無い): 消すものは無い")
    func newDeviceNothingToReset() {
        let p = LaunchRouting.plan(localUserId: nil, resolvedUserId: "u1", isNewAccount: false, intent: .login)
        #expect(p == .init(resetLocal: false, notice: nil))
    }

    @Test("新規会員登録を選んだが登録済みの電話番号: そのアカウントでログインしたと知らせる")
    func registerWithExistingPhone() {
        let p = LaunchRouting.plan(localUserId: nil, resolvedUserId: "u1", isNewAccount: false, intent: .register)
        #expect(p.notice == .alreadyRegistered)
    }

    @Test("ログインを選んだが未登録の電話番号: 新規登録として始めると知らせる")
    func loginWithNewPhone() {
        let p = LaunchRouting.plan(localUserId: nil, resolvedUserId: "u9", isNewAccount: true, intent: .login)
        #expect(p.notice == .notRegisteredYet)
    }

    @Test("新規会員登録で未登録の電話番号: お知らせなし")
    func registerWithNewPhone() {
        let p = LaunchRouting.plan(localUserId: nil, resolvedUserId: "u9", isNewAccount: true, intent: .register)
        #expect(p.notice == nil)
    }

    @Test("起動時の確認 (入口の選択なし): お知らせなし")
    func launchCheckHasNoNotice() {
        let p = LaunchRouting.plan(localUserId: "u1", resolvedUserId: "u1", isNewAccount: false, intent: nil)
        #expect(p.notice == nil)
    }

    // MARK: 途中でやめた登録・ログイン (最初からやり直す)

    @Test("登録・ログインを始めていない: やり直さない (いつもの再開)")
    func notStartedNoRestart() {
        #expect(LaunchRouting.restart(registrationInProgress: false, screen: .userInfo, hadLocalAccountBefore: false) == .none)
    }

    @Test("スプラッシュで「次へ」を押して終了: 最初からやり直す")
    func abandonedAfterTerms() {
        #expect(LaunchRouting.restart(registrationInProgress: true, screen: .login, hadLocalAccountBefore: false)
                == .startOver(clearLocalAccount: true))
    }

    @Test("SMS 認証のあと、プロフィール入力で終了: 最初からやり直し、途中で作った端末の状態も消す")
    func abandonedAtProfile() {
        #expect(LaunchRouting.restart(registrationInProgress: true, screen: .userInfo, hadLocalAccountBefore: false)
                == .startOver(clearLocalAccount: true))
    }

    @Test("4つの質問の途中で終了: 最初からやり直す")
    func abandonedAtOnboarding() {
        #expect(LaunchRouting.restart(registrationInProgress: true, screen: .onboarding, hadLocalAccountBefore: false)
                == .startOver(clearLocalAccount: true))
    }

    @Test("ホームまで来ていた: やり直さない")
    func reachedHomeNoRestart() {
        #expect(LaunchRouting.restart(registrationInProgress: true, screen: .home, hadLocalAccountBefore: false) == .none)
    }

    @Test("電話番号認証の前から使っている人がログインを途中でやめた: やり直すが、端末のデータは消さない")
    func legacyUserKeepsLocalData() {
        #expect(LaunchRouting.restart(registrationInProgress: true, screen: .login, hadLocalAccountBefore: true)
                == .startOver(clearLocalAccount: false))
    }
}
