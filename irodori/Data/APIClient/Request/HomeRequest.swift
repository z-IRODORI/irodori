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
    let model: String? = "gemini-3-pro-preview"   // "gemini-2.5-flash" or "gemini-2.5-flash-lite" or "gemini-3-pro-preview"
    let image_base64: String
}
