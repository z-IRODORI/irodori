//
//  ImageURLCache.swift
//  irodori
//
//  Created by Claude Code on 2026/02/17.
//

import Foundation

/// Firebase StorageのパスからダウンロードURLへのキャッシュ
@MainActor
final class ImageURLCache {
    static let shared = ImageURLCache()

    private var cache: [String: URL] = [:]

    private init() {}

    /// キャッシュからURLを取得
    func getURL(for path: String) -> URL? {
        return cache[path]
    }

    /// キャッシュにURLを保存
    func setURL(_ url: URL, for path: String) {
        cache[path] = url
    }

    /// キャッシュをクリア
    func clear() {
        cache.removeAll()
    }

    /// 特定のパスのキャッシュを削除
    func removeURL(for path: String) {
        cache.removeValue(forKey: path)
    }
}
