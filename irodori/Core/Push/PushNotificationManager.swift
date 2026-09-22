//
//  PushNotificationManager.swift
//  irodori
//
//  リモートプッシュ (FCM) の受け口。
//  - APNs トークンを Firebase Messaging に渡し (Phone Auth と共存)、FCM トークンをサーバに登録する
//  - フォアグラウンドでも通知バナーを出す
//  - 通知タップ → 該当コーデの詳細へ (MainTabView が pendingDestination を拾って push する)
//  通知の許可ダイアログは「玄関カメラとつながった」文脈で出す (DeviceSetupViewModel)。
//

import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseMessaging

@MainActor
@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    /// 通知タップで開くべき画面。MainTabView が消費して nil に戻す
    var pendingDestination: ViewType?

    private var fcmToken: String?
    private var registeredToken: String?
    private let client: PushTokenClientProtocol

    init(client: PushTokenClientProtocol = PushTokenClient()) {
        self.client = client
        super.init()
    }

    // MARK: - セットアップ (AppDelegate から)

    func configure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        // Phone Auth の検証用トークンと共存させる (setAPNSToken は AppDelegate 側で呼ぶ)
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - 許可とトークン登録

    /// 通知の許可を求め、許可されたら FCM トークンをサーバに登録する。
    /// 既に許可済みなら登録だけ (冪等)。
    @discardableResult
    func requestAuthorizationAndRegister() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        var granted = status == .authorized || status == .provisional
        if status == .notDetermined {
            granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        guard granted else { return false }
        UIApplication.shared.registerForRemoteNotifications()
        await registerTokenIfNeeded()
        return true
    }

    /// FCM トークンをサーバに送る (ログイン済み・トークン取得済み・未登録のときだけ)
    func registerTokenIfNeeded() async {
        if fcmToken == nil {
            fcmToken = try? await Messaging.messaging().token()
        }
        guard let token = fcmToken, token != registeredToken,
              let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue), !userId.isEmpty,
              let user = Auth.auth().currentUser,
              let idToken = try? await user.getIDToken() else { return }
        if (try? await client.register(token: token, userId: userId, idToken: idToken)) == true {
            registeredToken = token
        }
    }

    // MARK: - 受信内容の解釈

    nonisolated static func destination(from userInfo: [AnyHashable: Any]) -> ViewType? {
        guard let type = userInfo["type"] as? String, type == "device_capture",
              let coordinateId = userInfo["coordinate_id"] as? String, !coordinateId.isEmpty else { return nil }
        let image = (userInfo["image_url"] as? String) ?? ""
        return .coordinateDetail(.init(coordinateId: coordinateId, coordinateImageURL: image, showHeader: true))
    }
}

// MARK: - MessagingDelegate

extension PushNotificationManager: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            self.fcmToken = fcmToken
            // 許可済みのときだけ登録する (未許可でトークンだけ送っても届かない)
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .authorized || status == .provisional {
                await self.registerTokenIfNeeded()
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// フォアグラウンドでもバナーと音を出す
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// 通知タップ → コーデ詳細へ
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let destination = Self.destination(from: userInfo) else { return }
        await MainActor.run {
            self.pendingDestination = destination
        }
    }
}
