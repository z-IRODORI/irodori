//
//  StandardItemsClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/14.
//

import Foundation

protocol StandardItemsClientProtocol {
    func get(
        gender: String?,
        mainCategory: String?,
        subCategory: String?,
        color: String?,
        limit: Int
    ) async throws -> Result<StandardItemsResponse, HTTPError>
}

final class StandardItemsClient: StandardItemsClientProtocol {
    func get(
        gender: String?,
        mainCategory: String?,
        subCategory: String?,
        color: String?,
        limit: Int
    ) async throws -> Result<StandardItemsResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/standard-items"

        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return .failure(.responseError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // クエリパラメータを追加
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.responseError)
        }

        var queryItems: [URLQueryItem] = []
        if let gender = gender {
            queryItems.append(URLQueryItem(name: "gender", value: gender))
        }
        if let mainCategory = mainCategory {
            queryItems.append(URLQueryItem(name: "main_category", value: mainCategory))
        }
        if let subCategory = subCategory {
            queryItems.append(URLQueryItem(name: "sub_category", value: subCategory))
        }
        if let color = color {
            queryItems.append(URLQueryItem(name: "color", value: color))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))

        components.queryItems = queryItems
        request.url = components.url

        do {
            // URLSessionでリクエストを送信
            let (data, urlResponse) = try await URLSession.shared.data(for: request)

            // ステータスコードをチェック
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            // JSONレスポンスをデコード
            do {
                let response = try JSONDecoder().decode(StandardItemsResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            // キャンセルエラーの場合は特別に処理
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockStandardItemsClient: StandardItemsClientProtocol {
    func get(
        gender: String?,
        mainCategory: String?,
        subCategory: String?,
        color: String?,
        limit: Int
    ) async throws -> Result<StandardItemsResponse, HTTPError> {
        let mockItems = [
            StandardItem(
                id: "1",
                filename: "トップス_Tシャツ_ホワイト.png",
                storage_url: "https://storage.googleapis.com/irodori-77b17.appspot.com/standard-items/men/トップス_Tシャツ_ホワイト.png",
                main_category: "トップス",
                sub_category: "Tシャツ",
                color: "ホワイト",
                gender: "men",
                is_standard: true,
                file_size: 123456,
                uploaded_at: "2026-03-14T00:00:00Z"
            ),
            StandardItem(
                id: "2",
                filename: "ボトムス_ワイドパンツ_ブラック.png",
                storage_url: "https://storage.googleapis.com/irodori-77b17.appspot.com/standard-items/men/ボトムス_ワイドパンツ_ブラック.png",
                main_category: "ボトムス",
                sub_category: "ワイドパンツ",
                color: "ブラック",
                gender: "men",
                is_standard: true,
                file_size: 234567,
                uploaded_at: "2026-03-14T00:00:00Z"
            )
        ]

        return .success(StandardItemsResponse(
            status: "success",
            total_count: mockItems.count,
            items: mockItems,
            filters: StandardItemFilters(
                gender: gender,
                main_category: mainCategory,
                sub_category: subCategory,
                color: color,
                limit: limit
            )
        ))
    }
}
