//
//  CoordinateDisplay.swift
//  irodori
//
//  これまでのコーデ画像を「撮影画像」か「人物切り取り後画像」のどちらで
//  一覧表示するかは、各コーデが持つ display_type で決まる (コーデごとに選択)。
//  各レスポンスモデルの displayImageURL からこのリゾルバを使う。
//

import Foundation

enum CoordinateDisplayType: String, Codable {
    case captured   // 撮影画像
    case cutout     // 人物切り取り後画像
}

enum CoordinateImageResolver {
    /// display_type と両URLから、一覧/詳細に出す画像URLを解決する。
    /// "cutout" 指定でも切り取りURLが空なら撮影画像にフォールバックする。
    static func url(captured: String?, cutout: String?, displayType: String?) -> String? {
        if displayType == CoordinateDisplayType.cutout.rawValue,
           let cutout, !cutout.isEmpty {
            return cutout
        }
        return captured
    }
}
