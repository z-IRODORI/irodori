//
//  LoginView.swift
//  irodori
//
//  会員登録/ログインは「電話番号 (SMS認証)」のみ。入口は「新規会員登録」「ログイン」の2つを見せるが、
//  アカウントは選び方ではなく電話番号で決まる (AccountResolver)。食い違ったときはお知らせを出して進む。
//

import SwiftUI
import FirebaseAuth

struct LoginView: View {
    let onSignInSuccess: () -> Void

    @State private var isPresentedPhoneAuth = false
    @State private var intent: LaunchRouting.Intent = .register
    /// 認証のあと、サーバでアカウントを確かめている間
    @State private var resolving = false
    /// 選んだ入口と実際のアカウントが食い違ったときのお知らせ
    @State private var notice: LaunchRouting.Notice?

    var body: some View {
        ZStack {
            EntryBackground()

            VStack(spacing: 14) {
                Spacer()
                if resolving {
                    ProgressView().controlSize(.large)
                    Text("アカウントを確認しています")
                        .foregroundStyle(RenewalTokens.ink)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Button { start(.register) } label: {
                        Text("新規会員登録")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RenewalTokens.primaryFill)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
                    Button { start(.login) } label: {
                        Text("ログイン")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(RenewalTokens.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(RenewalTokens.ink, lineWidth: 1.2))
                    }
                    Text("どちらも電話番号の SMS 認証です。\n同じ電話番号なら、別の端末でもこれまでのデータに戻れます")
                        .foregroundStyle(RenewalTokens.muted)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $isPresentedPhoneAuth) {
            PhoneAuthView(onSignInSuccess: {
                isPresentedPhoneAuth = false
                // どちらを選んでも、アカウントは電話番号で決まる (選び方で別アカウントにならない)。
                // 選んだ入口と食い違ったときだけ、お知らせを出してから進む
                resolving = true
                Task { @MainActor in
                    let result = await AccountResolver.resolve(intent: intent)
                    resolving = false
                    if let result {
                        notice = result
                    } else {
                        onSignInSuccess()
                    }
                }
            })
        }
        .alert(noticeTitle, isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") {
                notice = nil
                onSignInSuccess()
            }
        } message: {
            Text(noticeMessage)
        }
    }

    private func start(_ intent: LaunchRouting.Intent) {
        Haptic.impact(.soft)
        self.intent = intent
        isPresentedPhoneAuth = true
    }

    private var noticeTitle: String {
        notice == .alreadyRegistered ? "登録済みの電話番号でした" : "まだ登録がありません"
    }

    private var noticeMessage: String {
        notice == .alreadyRegistered
            ? "この電話番号のアカウントでログインしました。これまでのデータを引き継いで始めます。"
            : "この電話番号のアカウントは見つかりませんでした。新規会員登録として始めます。"
    }
}

#Preview {
    LoginView(onSignInSuccess: {})
}
