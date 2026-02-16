//
//  UIImageCache.swift
//  irodori
//
//  Created by Claude Code on 2026/02/17.
//

import UIKit

/// UIImageのメモリキャッシュ
@MainActor
final class UIImageCache {
    static let shared = UIImageCache()

    private var cache: [String: UIImage] = [:]

    private init() {}

    /// キャッシュから画像を取得
    func getImage(for key: String) -> UIImage? {
        return cache[key]
    }

    /// キャッシュに画像を保存
    func setImage(_ image: UIImage, for key: String) {
        cache[key] = image
    }

    /// キャッシュをクリア
    func clear() {
        cache.removeAll()
    }

    /// 特定のキーのキャッシュを削除
    func removeImage(for key: String) {
        cache.removeValue(forKey: key)
    }
}
