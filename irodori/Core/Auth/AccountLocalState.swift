//
//  AccountLocalState.swift
//  irodori
//
//  新規会員登録で「新しく始める」ときに、アカウントに紐づく端末ローカル状態を一括初期化する。
//

import Foundation

enum AccountLocalState {
    /// 端末スコープの状態はアカウントを跨いで保持する
    private static let keepKeys: Set<UserDefaultsKey> = [
        .hasAgreedToTermsOfService,   // 利用規約への同意
        .notificationPromptShown,     // 通知プリプロンプトの表示済み記録
    ]

    /// 新規会員登録・退会用の初期化。userId を含む全アカウント状態を消すため、
    /// 既存データを引き継ぐ場合 (ログイン) では絶対に呼ばないこと。
    static func resetForNewRegistration() {
        for key in UserDefaultsKey.allCases where !keepKeys.contains(key) {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
        deleteProfileImageFiles()
        // 試着用の顔写真と生成結果キャッシュ。残すと次のアカウントに前の顔が写り込む
        FaceImageStore.shared.deleteAll()
    }

    /// Documents に保存されるプロフィール画像 (profile_*) を削除する。
    /// 残すと次のアカウントに前のアバターが写り込む。
    private static func deleteProfileImageFiles() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let fileURLs = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else { return }
        for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix("profile_") {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
