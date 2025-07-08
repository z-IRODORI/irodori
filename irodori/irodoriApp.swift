//
//  irodoriApp.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/19.
//

import SwiftUI

@main
struct irodoriApp: App {
    private let userDeufalts = UserDefaults.standard

    var body: some Scene {
        WindowGroup {
            // TODO: - スプラッシュ画面を実装して、そこで画面遷移を実行
            // 既存の実装では 利用規約を確認したこと や ユーザー情報を入力したこと を検知できないため画面遷移できない
            if !userDeufalts.bool(forKey: UserDefaultsKey.hasAgreedToTermsOfService.rawValue) {
                TermsOfServiceView(viewModel: TermsOfServiceViewModel())
            } else if userDeufalts.object(forKey: UserDefaultsKey.userInfo.rawValue) == nil {
                UserInfoView(viewModel: UserInfoViewModel())
            } else {
                CameraView()
            }

//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }
}
