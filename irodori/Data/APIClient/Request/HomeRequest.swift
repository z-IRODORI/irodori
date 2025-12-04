//
//  HomeRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/04.
//

import Foundation

struct HomeRequest: Encodable {
    let question: String
    let gender: String
    let image_base64: String
}
