//
//  LoginView.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみ。
//  入口で「はじめる (新規会員登録)」と「ログイン (データ引き継ぎ)」を分け、
//  会員登録は認証成功後にローカル状態を初期化してオンボーディングへ進める。
//

import SwiftUI

struct LoginView: View {
    let onSignInSuccess: () -> Void

    private enum AuthEntryMode {
        case register   // 新規会員登録: 認証後にローカル状態を初期化してオンボーディングへ
        case login      // ログイン: 端末のデータを引き継いで続きから再開
    }

    @State private var isPresentedPhoneAuth = false
    @State private var authMode: AuthEntryMode = .register
    @State private var showFreshStartConfirmation = false

    /// この端末に利用データ (プロフィール入力済み) が残っているか
    private var hasLocalData: Bool {
        UserDefaults.standard.object(forKey: UserDefaultsKey.userInfo.rawValue) != nil
    }

    var body: some View {
        ZStack {
            Image(.splash01)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(.logoWhite)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 50)

                    Text("今日のコーデに納得を、人生にIRODORIを")
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()

                VStack(spacing: 16) {
                    if hasLocalData {
                        Text("ご利用には電話番号認証が必要です。\nデータは「ログイン」からそのまま引き継げます。")
                            .foregroundStyle(.white)
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        if hasLocalData {
                            showFreshStartConfirmation = true
                        } else {
                            startPhoneAuth(mode: .register)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 17, weight: .medium))
                            Text("電話番号ではじめる")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .padding(.horizontal, 24)

                    Button {
                        startPhoneAuth(mode: .login)
                    } label: {
                        Text(hasLocalData ? "ログインはこちら（データを引き継ぐ）" : "アカウントをお持ちの方はログイン")
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .underline()
                    }

                    Text("SMSで届く6桁の認証コードで認証できます")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 12, weight: .regular))
                }
                .padding(.bottom, 48)
            }
        }
        .alert("新しく始めますか？", isPresented: $showFreshStartConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("引き継いでログイン") {
                startPhoneAuth(mode: .login)
            }
            Button("新しく始める", role: .destructive) {
                startPhoneAuth(mode: .register)
            }
        } message: {
            Text("この端末には利用データが残っています。新しく会員登録すると、これまでのコーデやクローゼットのデータは表示されなくなります。")
        }
        .sheet(isPresented: $isPresentedPhoneAuth) {
            PhoneAuthView(onSignInSuccess: {
                isPresentedPhoneAuth = false
                if authMode == .register {
                    // 新規会員登録: アカウント紐付きのローカル状態を初期化して
                    // プロフィール入力〜オンボーディングの全導線を通す
                    AccountLocalState.resetForNewRegistration()
                }
                onSignInSuccess()
            })
        }
    }

    private func startPhoneAuth(mode: AuthEntryMode) {
        authMode = mode
        isPresentedPhoneAuth = true
    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
