//
//  NotificationManager.swift
//  irodori
//
//  ローカル通知の管理 (21時の「明日の支度できたよ」)。
//  APNs 未整備のため、夜→朝の再訪ループはローカル通知だけで閉じる
//  (サーバプッシュはこのループの効果を数字で見てから投資する)。
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    /// 21時ティザー通知の識別子 (毎回この ID で置き換え登録する)
    private static let eveningIdentifier = "evening.teaser.21"
    static let eveningHour = 21

    /// 通知許可を求める。「これにする」直後 (達成感の直後) の文脈で呼ぶこと。
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 次の21時 (JST) に1回だけ発火する通知を置き換え登録する。
    /// body は当日 fetch 済みの相棒コメントを流用し、無ければ汎用文。未許可なら何もしない。
    func scheduleEveningTeaser(body: String?) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        center.removePendingNotificationRequests(withIdentifiers: [Self.eveningIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "明日の支度、できたよ"
        content.body = body ?? "明日の3コーデをそろえておいたよ。夜のうちにチラ見してみる？"
        content.sound = .default

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
        let now = Date()
        var target = cal.date(bySettingHour: Self.eveningHour, minute: 0, second: 0, of: now) ?? now
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.eveningIdentifier, content: content, trigger: trigger
        )
        try? await center.add(request)
    }

    /// 汎用文でのスケジュール (ホーム表示時)。明日タブの相棒コメントが
    /// 取得できたときは scheduleEveningTeaser(body:) が上書きする。
    func scheduleEveningTeaserIfNeeded() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == Self.eveningIdentifier }) else { return }
        await scheduleEveningTeaser(body: nil)
    }
}
