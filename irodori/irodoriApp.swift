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
    @Environment(\.scenePhase) var scenePhase

    @State private var path: [ViewType] = []
    var body: some Scene {
        WindowGroup {
            SplashView()
                .onAppear {
                    AnalyticsLogger.shared.log(screen: .splashScreenView)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        AnalyticsLogger.shared.log(action: .appBackground)
                    case .inactive:
                        AnalyticsLogger.shared.log(action: .appWillResignActive)
                    case .active:
                        AnalyticsLogger.shared.log(action: .appDidBecomeActive)
                    @unknown default:
                        break
                    }
                }

//            CameraView()

//            CoordinateReviewView(viewModel: .init(
//                coordinateImage: UIImage(resource: .coordinate2),
//                apiClient: FashionReviewClient()   //MockFashionReviewClient()
//            ), path: .constant([]))

//            RecommendCoordinateView(
//                viewModel: .init(recommendCoordinateClient: MockRecommendCoordinateClient())
//            )
        }
    }

}
