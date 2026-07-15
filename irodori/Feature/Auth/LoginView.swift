//
//  LoginView.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみ。
//  Apple サインインは一時停止中（コメントアウトで保持）。
//

import SwiftUI
// import AuthenticationServices   // Apple サインイン再開時に戻す

struct LoginView: View {
    let onSignInSuccess: () -> Void

    @State private var isPresentedPhoneAuth = false
//    @State private var currentNonce: String?
//    @State private var errorMessage: String?
//    @State private var isLoading = false

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

//                    if let errorMessage {
//                        Text(errorMessage)
//                            .foregroundStyle(.red)
//                            .font(.system(size: 13))
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal, 24)
//                    }
//
//                    if isLoading {
//                        ProgressView()
//                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                            .frame(height: 50)
//                            .frame(maxWidth: .infinity)
//                            .padding(.horizontal, 24)
//                    } else {
//                        SignInWithAppleButton(.signIn, onRequest: { request in
//                            let nonce = AuthManager.randomNonceString()
//                            currentNonce = nonce
//                            request.requestedScopes = [.fullName, .email]
//                            request.nonce = AuthManager.sha256(nonce)
//                        }, onCompletion: { result in
//                            handleAppleSignIn(result: result)
//                        })
//                        .signInWithAppleButtonStyle(.white)
//                        .frame(height: 50)
//                        .cornerRadius(25)
//                        .padding(.horizontal, 24)
//                    }
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

//    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
//        switch result {
//        case .success(let authorization):
//            guard
//                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
//                let nonce = currentNonce,
//                let idTokenData = credential.identityToken,
//                let idTokenString = String(data: idTokenData, encoding: .utf8)
//            else {
//                errorMessage = "Apple IDの認証情報を取得できませんでした"
//                return
//            }
//
//            isLoading = true
//            errorMessage = nil
//
//            Task {
//                do {
//                    try await AuthManager.shared.signInWithApple(
//                        idToken: idTokenString,
//                        nonce: nonce,
//                        fullName: credential.fullName
//                    )
//                    onSignInSuccess()
//                } catch {
//                    errorMessage = "サインインに失敗しました。もう一度お試しください。"
//                }
//                isLoading = false
//            }
//
//        case .failure(let error):
//            let nsError = error as NSError
//            // キャンセル（code 1001）は無視
//            if nsError.code != 1001 {
//                errorMessage = "サインインに失敗しました。もう一度お試しください。"
//            }
//        }
//    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
