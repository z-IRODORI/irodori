//
//  TryOnSource.swift
//  irodori
//
//  試着の入力ソース。
//  - closet: クローゼットのコーデ提案 (アイテム画像 2〜6 枚)
//  - snap:   おすすめコーデのスナップ写真 1 枚 (Pinterest 由来)
//

import Foundation
import CryptoKit

struct TryOnClosetItem: Hashable {
    let id: String
    let slot: String       // tops / bottoms / outer / shoes / accessory / bag
    let label: String      // 例 "トップス: ホワイト / シャツ"
    let imageURL: String
}

enum TryOnSource: Identifiable, Hashable {
    case closet(items: [TryOnClosetItem])
    case snap(id: String, imageURL: String, labels: [String])

    /// サーバ仕様と揃えたアイテム数の制約 (irodori-api/tryon_service.py)
    static let minClosetItems = 2
    static let maxClosetItems = 6

    var id: String {
        switch self {
        case .closet(let items):
            return "closet_" + items.map(\.id).sorted().joined(separator: "_")
        case .snap(let id, _, _):
            return "snap_\(id)"
        }
    }

    /// 生成コスト削減のための結果キャッシュキー。
    /// 顔ファイルのハッシュを混ぜているため、顔写真を変えると自動で無効になる。
    func cacheKey(faceHash: String) -> String {
        let digest = SHA256.hash(data: Data("\(faceHash)|\(id)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 表示用のサムネイル URL 群 (ローディング演出などで使う)
    var thumbnailURLs: [String] {
        switch self {
        case .closet(let items): return items.map(\.imageURL)
        case .snap(_, let imageURL, _): return [imageURL]
        }
    }
}
