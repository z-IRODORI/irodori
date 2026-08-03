//
//  ZOZOSearchURL.swift
//  irodori
//
//  ZOZOTOWN のアイテム検索URLを生成する共有ヘルパー。
//  p_keyv は UTF-8 ではなく Shift_JIS 系のパーセントエンコードを期待するため
//  (UTF-8 だと検索欄で文字化けする)、バックエンド closet_bridge_service と同じ仕様で
//  Shift_JIS に変換してからエンコードする。
//
//  NOTE: TomorrowPickSection の CoordComposition.zozoSearchURL と同一ロジック。
//  あちらは fileprivate のため共有できず、WIP が落ち着いたらこちらへの委譲に統一する。
//

import Foundation

enum ZOZOSearchURL {
    /// アイテムラベル (例: "黒 スラックス") から ZOZOTOWN 検索URLを生成する。
    /// ユーザーの性別 (メンズ/レディース) をキーワードに補って検索精度を上げる
    static func url(for label: String) -> URL? {
        let gender = Gender.fromWithDefault(
            UserDefaults.standard.string(forKey: UserDefaultsKey.gender.rawValue)
        )
        let genderKW = gender == .male ? "メンズ" : "レディース"
        var query = label
        if !query.contains(genderKW) {
            query += " " + genderKW
        }
        guard let data = query.data(using: .shiftJIS, allowLossyConversion: true), !data.isEmpty else {
            return URL(string: "https://zozo.jp/")
        }
        let encoded = data.map { byte -> String in
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x7E:
                return String(UnicodeScalar(byte))
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
        return URL(string: "https://zozo.jp/search/?p_keyv=\(encoded)")
    }
}
