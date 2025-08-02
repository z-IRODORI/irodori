//
//  MLError.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/28.
//

import Foundation

enum MLError: Error {
    // DetectHuman
    case notHuman

    // Segment
    case notTops
    case notBottoms
    case notTopsAndBottoms

    case unknwon

    var title: String {
        switch self {
        case .notHuman: return "全身認識エラー"
        case .notTops: return "トップス検出エラー"
        case .notBottoms: return "ボトムス検出エラー"
        case .notTopsAndBottoms: return "トップス&ボトムス検出エラー"
        case .unknwon: return "エラー"
        }
    }

    var errorDescription: String {
        switch self {
        case .notHuman:
            return "人物全体が写っていないか、人物が画像内に存在しない可能性があります。\n再度撮影してください。"
        case .notTops:
            return "画像内の人物からトップス領域を正しく検出できませんでした。"
        case .notBottoms:
            return "画像内の人物からボトムス領域を正しく検出できませんでした。"
        case .notTopsAndBottoms:
            return "トップスおよびボトムスの両方の領域を検出できませんでした。"
        case .unknwon:
            return "もう一度やり直してください。"
        }
    }
}
