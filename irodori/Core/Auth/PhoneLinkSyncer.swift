//
//  PhoneLinkSyncer.swift
//  irodori
//
//  電話番号 (Firebase Auth) とアプリ内 user_id の対応表をサーバへ同期する。
//  主目的は旧世代ユーザー (端末生成UUIDのuserId) の遡及紐付け:
//  すでに電話番号認証を済ませて使っているユーザーも、ホーム表示のたびに
//  ここを通るため、アプリ更新だけで自動的に紐付けが完成する。
//  新世代 (userId = Firebase UID) も同じ経路で自己紐付けを登録し、
//  機種変更復元 (linked-account) を全ユーザーで一様に効かせる。
//
//  成功した userId は UserDefaults に記録して再送しない (冪等・通信節約)。
//  失敗時は次回起動時に自動リトライになる。
//

import Foundation
import FirebaseAuth

@MainActor
enum PhoneLinkSyncer {
    static func syncIfNeeded(client: PhoneLinkClientProtocol = PhoneLinkClient()) async {
        guard let user = Auth.auth().currentUser,
              let userId = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue),
              !userId.isEmpty else { return }

        let syncedKey = UserDefaultsKey.phoneLinkSyncedUserId.rawValue
        guard UserDefaults.standard.string(forKey: syncedKey) != userId else { return }

        guard let idToken = try? await user.getIDToken() else { return }
        guard let result = try? await client.link(userId: userId, idToken: idToken),
              case .success = result else {
            // 失敗 (オフライン・409競合など) は記録せず、次回起動で再試行する。
            // 409 はサーバログで検知できる (別アカウント紐付け済みの異常ケース)
            return
        }
        UserDefaults.standard.set(userId, forKey: syncedKey)
    }
}
