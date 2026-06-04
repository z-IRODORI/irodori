//
//  FavoritesStore.swift
//  irodori
//
//  アプリ全体で共有する Observable ストア.
//  Environment に流して各 ViewModel/View から isFavorite/toggle を参照する.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class FavoritesStore {
    /// 一覧表示用 (created_at 降順)
    private(set) var favorites: [Favorite] = []
    /// 高速判定用 (kind, target_id) のセット
    private(set) var keys: Set<String> = []
    /// このセッション中にユーザーが明示的に setFavorite した key.
    /// レスポンスにキャッシュされた is_favorite ではなく store を信頼すべき項目を識別する.
    private(set) var touchedKeys: Set<String> = []

    private let client: FavoriteClientProtocol

    init(client: FavoriteClientProtocol = FavoriteClient()) {
        self.client = client
    }

    private static func key(kind: FavoriteKind, targetId: String) -> String {
        "\(kind.rawValue)|\(targetId)"
    }

    func isFavorite(kind: FavoriteKind, targetId: String) -> Bool {
        keys.contains(Self.key(kind: kind, targetId: targetId))
    }

    /// レスポンス側 `is_favorite` を初期表示のフォールバックに使う表示判定.
    /// ユーザーが一度でも setFavorite した項目は store を信頼し、サーバの古い値で上書きしない.
    func isFavoriteRespectingSession(
        kind: FavoriteKind,
        targetId: String,
        fallback: Bool
    ) -> Bool {
        let key = Self.key(kind: kind, targetId: targetId)
        if touchedKeys.contains(key) { return keys.contains(key) }
        return keys.contains(key) || fallback
    }

    func filtered(kind: FavoriteKind) -> [Favorite] {
        favorites.filter { $0.kindEnum == kind }
    }

    /// API からお気に入り一覧を再取得
    func refresh() async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { return }
        do {
            switch try await client.list(uid: uid, kind: nil) {
            case .success(let list):
                self.favorites = list
                self.keys = Set(list.map { Self.key(kind: $0.kindEnum, targetId: $0.target_id) })
            case .failure:
                break
            }
        } catch {}
    }

    /// 表示中のハートが切り替わった結果として呼ぶ. View 側で `!isFav` を渡して desired を明示する.
    /// 旧 `toggle` は store 内部状態のみで wasFavorite を判定していたため、
    /// レスポンス由来の is_favorite=true な項目を un-favorite できないバグがあった.
    func setFavorite(
        _ desired: Bool,
        kind: FavoriteKind,
        targetId: String,
        imageURL: String?,
        date: String? = nil
    ) async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { return }
        let cacheKey = Self.key(kind: kind, targetId: targetId)
        let favId = Favorite.favId(kind: kind, targetId: targetId)

        // 以降の表示判定は store を信頼する (サーバの古い is_favorite で覆らない)
        touchedKeys.insert(cacheKey)

        // 楽観更新
        applyLocal(desired: desired, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL, date: date)

        // 通信
        do {
            if desired {
                let result = try await client.add(uid: uid, kind: kind, targetId: targetId, imageURL: imageURL, date: date)
                if case .failure = result {
                    applyLocal(desired: !desired, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL, date: date)
                    ToastManager.shared.show("お気に入りの更新に失敗しました")
                }
            } else {
                let result = try await client.remove(uid: uid, favId: favId)
                if case .failure = result {
                    applyLocal(desired: !desired, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL, date: date)
                    ToastManager.shared.show("お気に入りの更新に失敗しました")
                }
            }
        } catch {
            applyLocal(desired: !desired, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL, date: date)
            ToastManager.shared.show("お気に入りの更新に失敗しました")
        }
    }

    private func applyLocal(
        desired: Bool,
        cacheKey: String,
        favId: String,
        kind: FavoriteKind,
        targetId: String,
        imageURL: String?,
        date: String?
    ) {
        if desired {
            keys.insert(cacheKey)
            if !favorites.contains(where: { $0.fav_id == favId }) {
                let now = ISO8601DateFormatter().string(from: Date())
                favorites.insert(
                    Favorite(
                        fav_id: favId,
                        kind: kind.rawValue,
                        target_id: targetId,
                        image_url: imageURL,
                        date: date,
                        created_at: now
                    ),
                    at: 0
                )
            }
        } else {
            keys.remove(cacheKey)
            favorites.removeAll { $0.fav_id == favId }
        }
    }
}
