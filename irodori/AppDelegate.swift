//
//  AppDelegate.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/09.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // アプリ起動時のログを送信
        AnalyticsLogger.shared.log(screen: .appLaunch)

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // アプリが終了する前にログを送信
        AnalyticsLogger.shared.log(action: .appTerminate)
    }

    // MARK: - Firebase Phone Auth (SMS認証)

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    // reCAPTCHA 認証後のリダイレクト URL を Firebase Auth に渡す
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Auth.auth().canHandle(url)
    }
}
