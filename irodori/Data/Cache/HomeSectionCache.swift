//
//  HomeSectionCache.swift
//  irodori
//
//  ホーム各セクションの前回レスポンスを UserDefaults に保存し、
//  次回表示時に即描画する (stale-while-revalidate)。
//  スケルトンは「キャッシュが無い初回」だけになり、体感の待ち時間を消す。
//

import Foundation

enum HomeSectionCache {
    private static func key(_ section: String, uid: String) -> String {
        "homeSectionCache_\(section)_\(uid)"
    }

    static func save<T: Encodable>(_ value: T, section: String, uid: String) {
        guard !uid.isEmpty, let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key(section, uid: uid))
    }

    static func load<T: Decodable>(_ type: T.Type, section: String, uid: String) -> T? {
        guard !uid.isEmpty,
              let data = UserDefaults.standard.data(forKey: key(section, uid: uid)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
