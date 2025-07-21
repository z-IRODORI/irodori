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
    var body: some Scene {
        WindowGroup {
//            SplashView()
//            CalendarView()
            SegmentationView()

//            CoordinateReviewView(
//                coordinateImage: UIImage(resource: .coordinate1),
//                fashionReview: .mock()
//            )
        }
    }

}
