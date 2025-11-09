//
//  AppDelegate.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/09.
//

import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // アプリ起動時のログを送信
        AnalyticsLogger.shared.log(screen: .appLaunch)

        return true
    }
}
