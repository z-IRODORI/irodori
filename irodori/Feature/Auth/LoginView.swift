//
//  LoginView.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみ。
//

import SwiftUI

struct LoginView: View {
    let onSignInSuccess: () -> Void

    @State private var isPresentedPhoneAuth = false

    /// 過去にユーザー情報を登録済み (= 認証必須化前からの既存ユーザー) か
    private var isExistingUser: Bool {
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

                VStack(spacing: 12) {
                    if isExistingUser {
                        Text("ご利用には電話番号認証が必要です。\nデータはそのまま引き継がれます。")
                            .foregroundStyle(.white)
                            .font(.system(size: 13, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        isPresentedPhoneAuth = true
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

                    Text("SMSで届く6桁の認証コードで登録・ログインできます")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 12, weight: .regular))
                }
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $isPresentedPhoneAuth) {
            PhoneAuthView(onSignInSuccess: {
                isPresentedPhoneAuth = false
                onSignInSuccess()
            })
        }
    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
