//
//  CoordinateResponse.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - Coordinate API Response Models

struct Coordinate: Codable {
    let id: String
    let user_id: String
    let date: String
    let coodinate_image_path: String
}

struct CoordinatesResponse: Codable {
    let user_id: String
    let coordinates: [Coordinate]
}

struct CoordinateResponse: Codable {
    let id: String
    let date: String
    let coodinate_image_path: String
}

struct DailyCoordinate: Codable {
    let date: String
    let id: String?
    let coodinate_image_path: String?
}