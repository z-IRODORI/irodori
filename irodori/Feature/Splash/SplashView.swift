//
//  SplashView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import SwiftUI

struct SplashView: View {
    @State var path: [ViewType] = []
    @State private var isPresentedTermsOfService = false
    @State private var isStateChanging = false  // state 変更中フラグ
    /// userId を復元できたらホームを作り直す (空の userId で読み込んだ画面を残さない)
    @State private var homeIdentity = 0
    /// サインイン済みなのに端末の情報が足りない (再インストール・別の端末) とき、サーバに確かめている間
    @State private var resolvingAccount: Bool
    /// この起動ですでにサーバに確かめたか (入力画面に進んだあと何度も確かめない)
    @State private var checkedAccountThisLaunch = false
    let viewModel: SplashViewModel = .init()
    let cameraViewModel: CameraViewModel = .init()
    private let toastManager = ToastManager.shared
    private let authManager = AuthManager.shared
    private var isHomeState: Bool {
        if case .home = viewModel.state { return true }
        return false
    }

    init() {
        viewModel.updateState()
        // 起動した瞬間に入力画面を一瞬見せないよう、確かめる必要があれば最初から「確認中」にしておく
        let needsCheck: Bool
        switch viewModel.state {
        case .userInfo, .onboarding: needsCheck = AuthManager.shared.isSignedIn
        default: needsCheck = false
        }
        _resolvingAccount = State(initialValue: needsCheck)
    }

    var body: some View {
        Group {
                switch viewModel.state {
                case .termsOfService:
                    SplashView()
                        .sheet(isPresented: $isPresentedTermsOfService) {
                            TermsOfServiceView(viewModel: .init(), hasAgreeToTermsOfService: {
                                viewModel.updateState()
                            })
                            // 同意するか「同意しない」を選ぶまで、下にスワイプで閉じさせない
                            .interactiveDismissDisabled()
                        }
                case .login:
                    LoginView {
                        viewModel.updateState()
                    }
                case .userInfo where resolvingAccount,
                     .onboarding where resolvingAccount:
                    // 入力画面やオンボーディングを一瞬見せないよう、確かめ終わるまで背景だけ出す
                    EntryBackground()
                        .overlay(alignment: .bottom) {
                            ProgressView().tint(.white).controlSize(.large).padding(.bottom, 80)
                        }
                case .userInfo:
                    InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
                        viewModel.setupSignUpDate()   // アプリインストールしてから一度しか呼ばれない想定
                        viewModel.updateState()
                    })
                case .onboarding, .fashionType, .selectStandardItem:
                    PartnerOnboardingFlowView(
                        showCloseButton: false,
                        onComplete: {
                            // 初めてのホームで、部品を指すツールチップを出す対象にする
                            CoachMarkCenter.shared.markEligible()
                            viewModel.viewedOnboarding()
                            UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasFashionTypeDiagnosis.rawValue)
                            UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasSelectedStandardItems.rawValue)
                            viewModel.updateState()
                        }
                    )
                case .home:
                    MainTabView()
                        .environment(AuthManager.shared)
                        .id(homeIdentity)
                        // サインイン済みなのに userId が無い (端末のアカウント状態だけ消えた) ときは
                        // 紐付け表から復元して、ホームを読み込み直す
                        .task {
                            if await PhoneLinkSyncer.restoreUserIdIfMissing() { homeIdentity += 1 }
                        }
                }
            }
            // .onChange(of: path) は削除済み（FirstTakePhotoView がオンボーディングから削除されたため不要）
            #if DEBUG
            // 改善案 >「初回オンボーディングからやり直す」
            .onReceive(NotificationCenter.default.publisher(for: OnboardingDebug.restartNotification)) { _ in
                viewModel.updateState()
            }
            #endif
            // 再インストールや別の端末で、Firebase のログインは残っているのに端末の情報が無いとき:
            // 入力画面・オンボーディングに進む前に、サーバのプロフィールと相棒を戻す
            .task {
                guard resolvingAccount else { return }
                checkedAccountThisLaunch = true
                await AccountResolver.resolve()
                resolvingAccount = false
                viewModel.updateState()
            }
            // 再インストール直後は利用規約が先に出るので、同意したあと入力画面・オンボーディングに
            // 進む時点でも確かめる (Firebase のログインはキーチェーンに残り、アプリを消しても消えない)
            .onChange(of: viewModel.state) { _, newState in
                guard !resolvingAccount, !checkedAccountThisLaunch, AuthManager.shared.isSignedIn else { return }
                guard newState == .userInfo || newState == .onboarding else { return }
                checkedAccountThisLaunch = true
                resolvingAccount = true
                Task { @MainActor in
                    await AccountResolver.resolve()
                    resolvingAccount = false
                    viewModel.updateState()
                }
            }
            .onChange(of: viewModel.state) { oldState, newState in
                // state が変わったときに path をクリアして、古い NavigationStack の履歴を削除
                print("🔍 [SplashView] State changed from \(oldState) to \(newState), clearing path")
                isStateChanging = true
                path.removeAll()
                // フラグをリセット（次のフレームで）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isStateChanging = false
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                // ログアウト / トークン失効時のみ .login へ戻す (サインイン時は onSignInSuccess 側で遷移済み)
                if !isAuthenticated {
                    viewModel.updateState()
                }
            }
//        case .userInfo:
//            InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
//                viewModel.setupSignUpDate()   // アプリインストールしてから一度しか呼ばれない想定
//                viewModel.updateState()
//            })
//        case .onboarding:
//            OnboardingView(closeButtonTapped: {
//                viewModel.viewedOnboarding()
//                viewModel.updateState()
//            })
//        case .home:
//            MainTabView()
        .overlay(alignment: .top) {
            if !isHomeState, let message = toastManager.message {
                ToastView(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: toastManager.message)
    }

    private func SplashView() -> some View {
        ZStack {
            EntryBackground()

            VStack(spacing: 12) {
                Text("サービスを開始することで以下の利用規約に同意したものとします")
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .regular))
                Button(action: {
                    AnalyticsLogger.shared.log(action: .termsAccepted, parameters: [
                        "action": GAEventAction.viewTerms.rawValue
                    ])
                    isPresentedTermsOfService = true
                }) {
                    Text("利用規約")
                        .foregroundStyle(.primary)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.bottom, 24)

                Button(action: {
                    AnalyticsLogger.shared.log(action: .termsAccepted, parameters: [
                        "action": GAEventAction.startService.rawValue
                    ])
                    viewModel.nextButtonTapped()
                }) {
                    Text("次へ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    SplashView()
}
