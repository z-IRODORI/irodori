//
//  RecommendCoordinateResponse.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/09/02.
//

import Foundation

struct RecommendCoordinateResponse: Codable {
    let coordinates: [RecommendCoordinate]
    let genres: [Genre]?
}

struct RecommendCoordinate: Codable, Hashable {
    let id: Int
    let image_url: String
    let pin_url_guess: String
}

struct Genre: Codable {
    let genre: String
    let count: Int
}

extension RecommendCoordinateResponse {
    static func mock() -> RecommendCoordinateResponse {
        return RecommendCoordinateResponse(
            coordinates: [
                RecommendCoordinate(id: 1, image_url: "https://i.pinimg.com/736x/a6/5a/50/a65a50686f1c10f5c98f2bedd434bf1e.jpg", pin_url_guess: "https://pinterest.com/pin/12345"),
                RecommendCoordinate(id: 2, image_url: "https://i.pinimg.com/736x/82/77/a9/8277a98095eda2e3b1435905296dd056.jpg", pin_url_guess: "https://pinterest.com/pin/67890"),
                RecommendCoordinate(id: 3, image_url: "https://i.pinimg.com/736x/ef/5c/fa/ef5cfadb23b246687241c487a4e8c733.jpg", pin_url_guess: "https://pinterest.com/pin/11111"),
                RecommendCoordinate(id: 4, image_url: "https://i.pinimg.com/736x/f1/4a/99/f14a99899c89588a6cac83481d4f6769.jpg", pin_url_guess: "https://pinterest.com/pin/22222"),
                RecommendCoordinate(id: 5, image_url: "https://i.pinimg.com/736x/3f/23/fa/3f23fa51d563253e78a5d31269d0d532.jpg", pin_url_guess: "https://pinterest.com/pin/33333")
            ],
            genres: [
                Genre(genre: "casual", count: 3),
                Genre(genre: "korean", count: 2)
            ]
        )
    }
}
