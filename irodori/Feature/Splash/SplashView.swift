//
//  SplashView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/09.
//

import SwiftUI

struct SplashView: View {
    let viewModel: SplashViewModel = .init()

    init() {
        viewModel.updateState()
    }

    var body: some View {
        // TODO: - スプラッシュ画面を実装して、そこで画面遷移を実行
        // 既存の実装では 利用規約を確認したこと や ユーザー情報を入力したこと を検知できないため画面遷移できない
        switch viewModel.state {
        case .termsOfService:
            TermsOfServiceView(viewModel: .init(), hasAgreeToTermsOfService: {
                viewModel.updateState()
            })
        case .userInfo:
            InputUserInfoView(viewModel: .init(), finishedInputUserInfo: {
                viewModel.updateState()
            })
        case .home:
            CameraView()
                .onAppear {
                    
                }
        }
    }
}

#Preview {
    SplashView()
}
