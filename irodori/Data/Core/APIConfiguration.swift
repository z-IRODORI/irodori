//
//  APIConfiguration.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

struct APIConfiguration {
    let baseURL: String
    let timeout: TimeInterval
    let decoder: JSONDecoder
    
    static let `default` = APIConfiguration(
        baseURL: "http://localhost:8080",
        timeout: 30.0,
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    )
    
    static let production = APIConfiguration(
        baseURL: "https://irodori.click",
        timeout: 30.0,
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
    )
}