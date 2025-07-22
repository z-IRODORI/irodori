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
//            SplashView()
//            CalendarView()
            CoordinateReviewView(viewModel: .init(
                coordinateImage: UIImage(resource: .coordinate2),
                apiClient: MockFashionReviewClient()
            ))

//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }
}
