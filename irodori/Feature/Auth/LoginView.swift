//
//  LoginView.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみで、入口は1つ。
//  認証のあと AccountResolver が電話番号からアカウントを決め、プロフィール・相棒の状態を戻す
//  (以前は「はじめる / ログイン」を選ばせていて、同じ人でも選び方で別アカウントになることがあった)。
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    let onSignInSuccess: () -> Void

    @State private var isPresentedPhoneAuth = false
    /// 認証のあと、サーバでアカウントを確かめている間
    @State private var resolving = false

    var body: some View {
        ZStack {
            EntryBackground()

            VStack(spacing: 16) {
                Spacer()
                if resolving {
                    ProgressView().controlSize(.large)
                    Text("アカウントを確認しています")
                        .foregroundStyle(RenewalTokens.ink)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Button {
                        isPresentedPhoneAuth = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 17, weight: .medium))
                            Text("電話番号ではじめる・ログイン")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(RenewalTokens.primaryFill)
                        .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    .padding(.horizontal, 24)

                    Text("はじめての方も、別の端末で使っていた方も同じボタンです。\n同じ電話番号なら、これまでのデータにそのまま戻れます")
                        .foregroundStyle(RenewalTokens.muted)
                        .font(.system(size: 12, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $isPresentedPhoneAuth) {
            PhoneAuthView(onSignInSuccess: {
                isPresentedPhoneAuth = false
                // 「新規登録かログインか」は聞かない。電話番号でアカウントを決め、
                // 端末に別の人の状態が残っていれば消し、サーバのプロフィール・相棒を戻してから進む
                resolving = true
                Task { @MainActor in
                    await AccountResolver.resolve()
                    resolving = false
                    onSignInSuccess()
                }
            })
        }
    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
