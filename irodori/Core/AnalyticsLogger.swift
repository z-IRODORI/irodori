//
//  AnalyticsLogger.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/09.
//

import Foundation
import FirebaseAnalytics

final class AnalyticsLogger {
    static let shared = AnalyticsLogger()

    private init() {}

    func log(screen: GAEventScreen, parameters: [String: Any]? = nil) {
        Analytics.logEvent(screen.rawValue, parameters: parameters)
    }
    
    func log(action: GAEventAction, parameters: [String: Any]? = nil) {
        Analytics.logEvent(action.rawValue, parameters: parameters)
    }
    
    func log(error: GAEventError, parameters: [String: Any]? = nil) {
        Analytics.logEvent(error.rawValue, parameters: parameters)
    }

    // MARK: - User Identification

    /// ユーザーIDを設定（ログイン時に呼び出し）
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    /// ユーザープロパティを設定
    func setUserProperty(value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// よく使うユーザープロパティの設定
    func setUserProperties(
        gender: String? = nil,
        ageGroup: String? = nil,
        fashionStyle: String? = nil,
        premiumUser: Bool? = nil
    ) {
        if let gender = gender {
            Analytics.setUserProperty(gender, forName: "gender")
        }
        if let ageGroup = ageGroup {
            Analytics.setUserProperty(ageGroup, forName: "age_group")
        }
        if let fashionStyle = fashionStyle {
            Analytics.setUserProperty(fashionStyle, forName: "fashion_style")
        }
        if let premiumUser = premiumUser {
            Analytics.setUserProperty(premiumUser ? "true" : "false", forName: "premium_user")
        }
    }
}
