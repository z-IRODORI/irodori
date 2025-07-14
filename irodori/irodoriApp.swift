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
            SplashView()
//            CalendarView()
//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate2),
//                fashionReview: .mock()
//            )


//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }
}
