//
//  GAEvent.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/09.
//

import Foundation

enum GAEvent: String {
    case appLaunch
    
    // Screen Views
    case splashScreenView
    case onboardingScreenView
    case cameraScreenView
    case coordinateReviewScreenView
    case recommendCoordinateScreenView
    case memoryCalendarScreenView
    case coordinateDetailScreenView
    case userInfoScreenView
    case termsOfServiceScreenView
    
    // User Actions
    case photoTaken
    case photoSelected
    case coordinateReviewed
    case recommendationRequested
    case calendarDateSelected
    case userInfoSubmitted
    case termsAccepted
    
    // Errors
    case apiError
    case cameraError
    case mlError
}
