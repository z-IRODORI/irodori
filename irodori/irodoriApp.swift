//
//  irodoriApp.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/19.
//

import SwiftUI

@main
struct irodoriApp: App {
    @StateObject private var termsViewModel = TermsOfServiceViewModel()
    
    var body: some Scene {
        WindowGroup {
            if termsViewModel.hasAgreedToTerms {
                CameraView()
            } else {
                TermsOfServiceView()
            }

//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }
}
