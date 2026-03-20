//
//  ChatRequest.swift
//  irodori
//
//  Created by yuki.hamada on 2026/02/09.
//

import Foundation

struct ChatRequest: Encodable {
    let question: String
    let gender: Gender
    let model: String? = "gemini-3-pro-preview"   // "gemini-2.5-flash" or "gemini-2.5-flash-lite" or "gemini-3-pro-preview"
    let image_base64: String
}
