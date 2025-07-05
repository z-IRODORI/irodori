//
//  HTTPMethod.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

enum HTTPMethod: String, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}