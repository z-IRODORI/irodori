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
    @State private var path: [ViewType] = []
    var body: some Scene {
        WindowGroup {
            SplashView()
//            CalendarView()
//            SegmentationView()
//            OnboardingView(closeButtonTapped: {})

//            CoordinateReviewView(viewModel: .init(
//                coordinateImage: UIImage(resource: .coordinate2),
//                apiClient: MockFashionReviewClient()
//            ), path: .constant([]))

//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }

}
