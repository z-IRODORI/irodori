//
//  CoordinateMockData.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - DailyCoordinate Mock Data

extension DailyCoordinate {
    static func mockData() -> DailyCoordinate {
        return DailyCoordinate(
            date: "2025-07-04",
            id: "coord123",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
    
    static func mockDataList(count: Int = 7) -> [DailyCoordinate] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<count).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let dateString = DateFormatter.yyyyMMdd.string(from: date)
            
            return DailyCoordinate(
                date: dateString,
                id: dayOffset == 0 ? nil : "coord\(dayOffset)",
                coodinate_image_path: dayOffset == 0 ? nil : "https://example.com/coordinate\(dayOffset).jpg"
            )
        }
    }
}

// MARK: - CoordinateResponse Mock Data

extension CoordinateResponse {
    static func mockData() -> CoordinateResponse {
        return CoordinateResponse(
            id: "coord123",
            date: "2025-07-04",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
}

// MARK: - APICoordinateItem Mock Data

extension APICoordinateItem {
    static func mockData() -> APICoordinateItem {
        return APICoordinateItem(
            id: "item123",
            coordinate_id: "coord123",
            item_type: "top",
            item_image_path: "https://example.com/item.jpg"
        )
    }
    
    static func mockDataList(coordinateId: String = "coord123") -> [APICoordinateItem] {
        let itemTypes = ["top", "bottom", "shoes", "accessory"]
        
        return itemTypes.enumerated().map { index, type in
            APICoordinateItem(
                id: "item\(index + 1)",
                coordinate_id: coordinateId,
                item_type: type,
                item_image_path: "https://example.com/\(type).jpg"
            )
        }
    }
}

// MARK: - APICoordinateResponseDetail Mock Data

extension APICoordinateResponseDetail {
    static func mockData() -> APICoordinateResponseDetail {
        return APICoordinateResponseDetail(
            id: "coord123",
            date: "2025-07-04",
            coodinate_image_path: "https://example.com/coordinate.jpg"
        )
    }
    
    static func mockDataList(count: Int = 5) -> [APICoordinateResponseDetail] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<count).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let dateString = DateFormatter.yyyyMMdd.string(from: date)
            
            return APICoordinateResponseDetail(
                id: "coord\(dayOffset + 1)",
                date: dateString,
                coodinate_image_path: "https://example.com/coordinate\(dayOffset + 1).jpg"
            )
        }
    }
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}