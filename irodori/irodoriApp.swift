//
//  irodoriApp.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/19.
//

import SwiftUI
import CoreML
import Vision

@main
struct irodoriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var path: [ViewType] = []
    var body: some Scene {
        WindowGroup {
            SplashView()
                .onAppear {
                    AnalyticsLogger.shared.log(event: .splashScreenView)
                }

//            CameraView()

//            CoordinateReviewView(viewModel: .init(
//                coordinateImage: UIImage(resource: .coordinate2),
//                apiClient: MockFashionReviewClient()
//            ), path: .constant([]))

//            RecommendCoordinateView(
//                viewModel: .init(recommendCoordinateClient: MockRecommendCoordinateClient())
//            )
        }
    }

}
