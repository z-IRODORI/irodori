//
//  SplashView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import SwiftUI

struct SplashView: View {
    @State private var isPresentedTermsOfService = false
    let viewModel: SplashViewModel = .init()

    init() {
        viewModel.updateState()
    }

    var body: some View {
        // TODO: - スプラッシュ画面を実装して、そこで画面遷移を実行
        // 既存の実装では 利用規約を確認したこと や ユーザー情報を入力したこと を検知できないため画面遷移できない
        switch viewModel.state {
        case .termsOfService:
            SplashView()
                .sheet(isPresented: $isPresentedTermsOfService) {
                    TermsOfServiceView(viewModel: .init(), hasAgreeToTermsOfService: {
                        viewModel.updateState()
                    })
                }
        case .userInfo:
            InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
                viewModel.setupSignUpDate()   // アプリインストールしてから一度しか呼ばれない想定
                viewModel.updateState()
            })
        case .home:
            CameraView()
        }
    }

    private func SplashView() -> some View {
        ZStack {
            Image(.splash01)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Image(.logoWhite)
                    .resizable()
                    .frame(width: 250, height: 50)
                Text("今日のコーデに納得を、人生にIRODORIを")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(spacing: 12) {
                Text("サービスを開始することで以下の利用規約に同意したものとします")
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .regular))
                Button(action: {
                    isPresentedTermsOfService = true
                }) {
                    Text("利用規約")
                        .foregroundStyle(.primary)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.bottom, 24)

                Button(action: {
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
        .ignoresSafeArea()
    }
}

#Preview {
    SplashView()
}
