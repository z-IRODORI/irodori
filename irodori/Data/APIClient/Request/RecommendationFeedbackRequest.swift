//
//  RecommendationFeedbackRequest.swift
//  irodori
//
//  おすすめコーデへのフィードバック (好み/興味なし) リクエスト。
//  サーバ側でテイストベクトルと候補選定に反映されパーソナライズが改善される。
//

import Foundation

struct RecommendationFeedbackRequest: Encodable {
    let pool_id: String
    let rating: String          // "like" | "dislike"
    let reasons: [String]       // dislike の理由チップ (任意)
    let target_date: String?    // 表示していた対象日 (任意)
}
