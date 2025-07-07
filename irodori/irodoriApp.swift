//
//  irodoriApp.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/19.
//

import SwiftUI

@main
struct irodoriApp: App {
    private var termsViewModel = TermsOfServiceViewModel()
    private var userInfoViewModel = UserInfoViewModel()
    
    var body: some Scene {
        WindowGroup {
            if !termsViewModel.hasAgreedToTerms {
                TermsOfServiceView(viewModel: termsViewModel)
            } else if !userInfoViewModel.hasCompletedUserInfo {
                UserInfoView(viewModel: userInfoViewModel)
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
