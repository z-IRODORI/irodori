//
//  HTTPMethod.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

enum HTTPMethod: String, CaseIterable {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
    case HEAD = "HEAD"
    case OPTIONS = "OPTIONS"
}