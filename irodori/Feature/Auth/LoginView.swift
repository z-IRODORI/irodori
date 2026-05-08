//
//  LoginView.swift
//  irodori
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    let onSignInSuccess: () -> Void

    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

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
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                    } else {
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            let nonce = AuthManager.randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = AuthManager.sha256(nonce)
                        }, onCompletion: { result in
                            handleAppleSignIn(result: result)
                        })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(25)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let idTokenData = credential.identityToken,
                let idTokenString = String(data: idTokenData, encoding: .utf8)
            else {
                errorMessage = "Apple IDの認証情報を取得できませんでした"
                return
            }

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    try await AuthManager.shared.signInWithApple(
                        idToken: idTokenString,
                        nonce: nonce,
                        fullName: credential.fullName
                    )
                    onSignInSuccess()
                } catch {
                    errorMessage = "サインインに失敗しました。もう一度お試しください。"
                }
                isLoading = false
            }

        case .failure(let error):
            let nsError = error as NSError
            // キャンセル（code 1001）は無視
            if nsError.code != 1001 {
                errorMessage = "サインインに失敗しました。もう一度お試しください。"
            }
        }
    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
