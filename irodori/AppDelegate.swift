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

        // Firebase 匿名認証
        authenticateAnonymously()

        // アプリ起動時のログを送信
        AnalyticsLogger.shared.log(screen: .appLaunch)

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // アプリが終了する前にログを送信
        AnalyticsLogger.shared.log(action: .appTerminate)
    }

    // MARK: - Firebase Anonymous Authentication

    private func authenticateAnonymously() {
        Task { @MainActor in
            // 既にログイン済みかチェック
            if Auth.auth().currentUser != nil {
                return
            }

            // AuthManagerを使用して匿名ログイン
            do {
                try await AuthManager.shared.signInAnonymously()
            } catch {
                // エラーが発生しても致命的ではないため、アプリは継続
            }
        }
    }
}
