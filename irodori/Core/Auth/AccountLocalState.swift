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

    /// UserDefaultsKey の外で、人ごとに違う内容を保存しているキー (前の人の表示が残らないように一緒に消す)
    private static let accountScopedPrefixes = [
        "renewalHome.",          // 前回の3案の控え・相棒のひとこと・最近選んだ主役の服
        "homeSectionCache_",     // ホーム下部の前回レスポンス
        "analysisJob.",          // 解析中のジョブ (前の人の解析トースターが出る)
    ]
    private static let accountScopedKeys = ["coachMark.seen", "coachMark.eligible"]

    /// 新規会員登録・退会・別の人のアカウントに切り替わったときの初期化。userId を含む全アカウント状態を消すため、
    /// 同じ人のデータを引き継ぐ場合 (ログイン) では呼ばないこと。
    @MainActor
    static func resetForNewRegistration() {
        let defaults = UserDefaults.standard
        for key in UserDefaultsKey.allCases where !keepKeys.contains(key) {
            defaults.removeObject(forKey: key.rawValue)
        }
        for key in defaults.dictionaryRepresentation().keys
        where accountScopedPrefixes.contains(where: { key.hasPrefix($0) }) || accountScopedKeys.contains(key) {
            defaults.removeObject(forKey: key)
        }
        // メモリに残っている前の人の状態も消す
        AnalysisJobStore.shared.cancel()
        CoachMarkCenter.shared.resetForNewAccount()
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
