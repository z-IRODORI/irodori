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

    /// 楽観更新でお気に入りを切替. 失敗時は元に戻す.
    func toggle(kind: FavoriteKind, targetId: String, imageURL: String?) async {
        let uid = UserDefaults.standard.string(forKey: UserDefaultsKey.userId.rawValue) ?? ""
        guard !uid.isEmpty else { return }
        let cacheKey = Self.key(kind: kind, targetId: targetId)
        let favId = Favorite.favId(kind: kind, targetId: targetId)
        let wasFavorite = keys.contains(cacheKey)

        // 楽観更新
        if wasFavorite {
            keys.remove(cacheKey)
            favorites.removeAll { $0.fav_id == favId }
        } else {
            keys.insert(cacheKey)
            let now = ISO8601DateFormatter().string(from: Date())
            favorites.insert(
                Favorite(
                    fav_id: favId,
                    kind: kind.rawValue,
                    target_id: targetId,
                    image_url: imageURL,
                    created_at: now
                ),
                at: 0
            )
        }

        // 通信
        do {
            if wasFavorite {
                let result = try await client.remove(uid: uid, favId: favId)
                if case .failure = result { rollback(wasFavorite: wasFavorite, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL) }
            } else {
                let result = try await client.add(uid: uid, kind: kind, targetId: targetId, imageURL: imageURL)
                if case .failure = result { rollback(wasFavorite: wasFavorite, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL) }
            }
        } catch {
            rollback(wasFavorite: wasFavorite, cacheKey: cacheKey, favId: favId, kind: kind, targetId: targetId, imageURL: imageURL)
        }
    }

    private func rollback(wasFavorite: Bool, cacheKey: String, favId: String, kind: FavoriteKind, targetId: String, imageURL: String?) {
        if wasFavorite {
            keys.insert(cacheKey)
            let now = ISO8601DateFormatter().string(from: Date())
            favorites.insert(
                Favorite(fav_id: favId, kind: kind.rawValue, target_id: targetId, image_url: imageURL, created_at: now),
                at: 0
            )
        } else {
            keys.remove(cacheKey)
            favorites.removeAll { $0.fav_id == favId }
        }
        ToastManager.shared.show("お気に入りの更新に失敗しました")
    }
}
