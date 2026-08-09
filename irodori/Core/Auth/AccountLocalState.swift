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

    /// 新規会員登録用の初期化。userId を含む全アカウント状態を消すため、
    /// 既存データを引き継ぐ場合 (ログイン) では絶対に呼ばないこと。
    static func resetForNewRegistration() {
        for key in UserDefaultsKey.allCases where !keepKeys.contains(key) {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
    }
}
