//
//  CoordinateRequests.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - Get Coordinates Request

struct GetCoordinatesRequest: APIRequestProtocol {
    typealias Response = [DailyCoordinate]
    
    let path: String
    let method: HTTPMethod = .GET
    let queryItems: [URLQueryItem]?
    
    init(userId: String, page: Int = 0) {
        self.path = "/api/coordinate/list/\(userId)"
        self.queryItems = [URLQueryItem(name: "page", value: "\(page)")]
    }
}

// MARK: - Create Coordinate Request

struct CreateCoordinateRequest: JSONRequestProtocol {
    typealias Response = CoordinateResponse
    typealias RequestBody = CoordinateRequest
    
    let path: String = "/api/coordinate"
    let method: HTTPMethod = .POST
    let requestBody: CoordinateRequest?
    
    init(coordinateRequest: CoordinateRequest) {
        self.requestBody = coordinateRequest
    }
}

// MARK: - Get Coordinate Items Request

struct GetCoordinateItemsRequest: APIRequestProtocol {
    typealias Response = [APICoordinateItem]
    
    let path: String
    let method: HTTPMethod = .GET
    
    init(coordinateId: String) {
        self.path = "/api/coordinate-item/\(coordinateId)"
    }
}