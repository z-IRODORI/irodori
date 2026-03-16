//
//  BulkCoordinateRecommendClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/15.
//

import Foundation

// MARK: - Request Models

struct BulkCoordinateRecommendItem: Codable {
    let item_id: String?
    let gender: String
    let input_type: String
    let category: String
    let text: String
    let num_outfits: Int
    let num_candidates: Int
}

struct BulkCoordinateRecommendRequest: Codable {
    let items: [BulkCoordinateRecommendItem]
}

// MARK: - Response Models

struct CoordinateRecommendResult: Codable {
    let item_id: String?
    let index: Int
    let status: String
    let input_type: String
    let category: String
    let text: String
    let recommend_coordinates: [CoordinateRecommend]?
    let outer_list: [String]?
    let tops_list: [String]?
    let bottoms_list: [String]?
    let shoes_list: [String]?
    let accessories_list: [String]?
    let error: String?
}

struct BulkCoordinateRecommendResponse: Codable {
    let status: String
    let total_count: Int
    let success_count: Int
    let failed_count: Int
    let results: [CoordinateRecommendResult]
    let processing_time_ms: Double?
}

// MARK: - Client Protocol

protocol BulkCoordinateRecommendClientProtocol {
    func post(request: BulkCoordinateRecommendRequest) async throws -> Result<BulkCoordinateRecommendResponse, HTTPError>
}

// MARK: - Implementation

final class BulkCoordinateRecommendClient: BulkCoordinateRecommendClientProtocol {
    func post(request: BulkCoordinateRecommendRequest) async throws -> Result<BulkCoordinateRecommendResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/coordinate-recommend/bulk"

        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return .failure(.responseError)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60.0  // 複数アイテムの処理のため長めに設定

        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
        } catch {
            return .failure(.badRequest)
        }

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)

            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            do {
                let response = try JSONDecoder().decode(BulkCoordinateRecommendResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockBulkCoordinateRecommendClient: BulkCoordinateRecommendClientProtocol {
    func post(request: BulkCoordinateRecommendRequest) async throws -> Result<BulkCoordinateRecommendResponse, HTTPError> {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let mockResults = request.items.enumerated().map { index, item in
            CoordinateRecommendResult(
                item_id: item.item_id,
                index: index,
                status: "success",
                input_type: item.input_type,
                category: item.category,
                text: item.text,
                recommend_coordinates: [
                    CoordinateRecommend(
                        coordinate_image_path: "coordinates/google/071248eb61c5083d4537f4e973652b0d.png",
                        outer: nil,
                        tops: ItemDetail(
                            name: "トップス_パーカー_グレー",
                            image_paths: ["items/トップス_パーカー_グレー/00.png"]
                        ),
                        bottoms: nil,
                        shoes: ItemDetail(
                            name: "シューズ_サンダル_ブラック",
                            image_paths: ["items/シューズ_サンダル_ブラック/00.png"]
                        ),
                        accessories: nil
                    )
                ],
                outer_list: ["アウター1", "アウター2"],
                tops_list: ["トップス1", "トップス2"],
                bottoms_list: ["ボトムス1", "ボトムス2"],
                shoes_list: ["シューズ1", "シューズ2"],
                accessories_list: nil,
                error: nil
            )
        }

        return .success(BulkCoordinateRecommendResponse(
            status: "success",
            total_count: request.items.count,
            success_count: request.items.count,
            failed_count: 0,
            results: mockResults,
            processing_time_ms: 1234.5
        ))
    }
}
