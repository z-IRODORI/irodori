//
//  GAEvent.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/09.
//

import Foundation

enum GAEventScreen: String {
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
}

enum GAEventAction: String {
    // User Actions
    case photoTaken
    case photoSelected
    case coordinateReviewed
    case recommendationRequested
    case calendarDateSelected
    case userInfoSubmitted
    case termsAccepted
    
    // Navigation Actions
    case goHome = "go_home"
    case backToCamera = "back_to_camera"
    case nextPage = "next_page"
    case closeOnboarding = "close_onboarding"
    
    // User Interactions
    case viewTerms = "view_terms"
    case startService = "start_service"
    case photoLibrary = "photo_library"
    case camera = "camera"
    case cameraHeaderButton = "camera_header"
    case helpButton = "camera_help_button"
    
    // Content Sources
    case coordinateReview = "coordinate_review"
    case coordinateDetail = "coordinate_detail"
    
    // App Lifecycle
    case appBackground = "app_background"
    case appTerminate = "app_terminate"
    case appWillResignActive = "app_will_resign_active"
    case appDidBecomeActive = "app_did_become_active"
}

enum GAEventError: String {
    case apiError
    case cameraError
    case mlError
    case phoneAuthError = "phone_auth_error"
}
