//
//  TryOnCache.swift
//  irodori
//
//  試着結果画像のディスクキャッシュ (Caches/TryOn/<key>)。
//  キーは TryOnSource.cacheKey(faceHash:) — 同じ顔 × 同じコーデの再タップは
//  生成 API を呼ばず即表示するためのコスト削減装置。
//

import UIKit

final class TryOnCache {
    static let shared = TryOnCache()
    private init() {}

    private let maxCount = 30

    private var directory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TryOn", isDirectory: true)
    }

    private func fileURL(for key: String) -> URL? {
        directory?.appendingPathComponent(key)
    }

    func imageData(for key: String) -> Data? {
        guard let url = fileURL(for: key) else { return nil }
        return try? Data(contentsOf: url)
    }

    func image(for key: String) -> UIImage? {
        imageData(for: key).flatMap(UIImage.init(data:))
    }

    func store(_ data: Data, for key: String) {
        guard let directory, let url = fileURL(for: key) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        trim()
    }

    func clear() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// 古い順に間引いて maxCount 件までに保つ
    private func trim() {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        guard files.count > maxCount else { return }
        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return l < r
        }
        for url in sorted.prefix(files.count - maxCount) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
