//
//  WearMarkRequest.swift
//  irodori
//
//  ユーザーが推薦コーデを「これを今日着る」とマークするリクエスト
//

import Foundation

struct WearMarkRequest: Encodable {
    let pool_id: String
    let worn_date: String  // YYYY-MM-DD
}
