//
//  OnboardingDebug.swift
//  irodori
//
//  初回オンボーディング (ウォークスルー → 4つの質問 → 相棒誕生 → ホームのツールチップ) を
//  何度でも確かめるための DEBUG 専用の操作。ホームの「改善案」から使う。
//

#if DEBUG
import Foundation

enum OnboardingDebug {
    static let dryRunKey = "debug.onboardingDryRun"
    static let restartNotification = Notification.Name("debug.restartOnboarding")

    /// true のあいだ、4つの質問の答えを本番に保存しない (既定は true)
    static var dryRun: Bool {
        UserDefaults.standard.object(forKey: dryRunKey) as? Bool ?? true
    }

    /// 新規ユーザーと同じく、ウォークスルーから始め直す (ツールチップも未表示に戻す)
    @MainActor
    static func restartFirstRun() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.hasOnboarding.rawValue)
        CoachMarkCenter.shared.resetForDebug()
        NotificationCenter.default.post(name: restartNotification, object: nil)
    }
}
#endif
