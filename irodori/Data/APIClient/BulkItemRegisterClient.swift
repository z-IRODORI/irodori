//
//  BulkItemRegisterClient.swift
//  irodori
//
//  Created by yuki.hamada on 2026/03/15.
//

import Foundation

protocol BulkItemRegisterClientProtocol {
    func register(
        userId: String,
        userToken: String,
        items: [(metadata: BulkItemMetadata, imageData: Data)]
    ) async throws -> Result<BulkItemRegistrationResponse, HTTPError>
}

final class BulkItemRegisterClient: BulkItemRegisterClientProtocol {
    func register(
        userId: String,
        userToken: String,
        items: [(metadata: BulkItemMetadata, imageData: Data)]
    ) async throws -> Result<BulkItemRegistrationResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/items/register/bulk"

        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return .failure(.responseError)
        }

        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add user_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)

        // Add user_token
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userToken)\r\n".data(using: .utf8)!)

        // Add items_metadata as JSON array
        let metadataArray = items.map { $0.metadata }

        do {
            let jsonData = try JSONEncoder().encode(metadataArray)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"items_metadata\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(jsonString)\r\n".data(using: .utf8)!)
        } catch {
            return .failure(.decodeError)
        }

        // Add images
        for (index, item) in items.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"item_\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(item.imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 120.0
            config.timeoutIntervalForResource = 120.0
            let session = URLSession(configuration: config)

            let (data, urlResponse) = try await session.data(for: request)

            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode

                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            do {
                let response = try JSONDecoder().decode(BulkItemRegistrationResponse.self, from: data)
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

final class MockBulkItemRegisterClient: BulkItemRegisterClientProtocol {
    func register(
        userId: String,
        userToken: String,
        items: [(metadata: BulkItemMetadata, imageData: Data)]
    ) async throws -> Result<BulkItemRegistrationResponse, HTTPError> {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let registeredItems = items.enumerated().map { index, item in
            RegisteredItem(
                id: "mock-\(index)",
                storage_url: "https://example.com/image_\(index).jpg",
                gender: item.metadata.gender,
                main_category: item.metadata.main_category,
                sub_category: item.metadata.sub_category,
                color: item.metadata.color,
                item_type: item.metadata.item_type,
                category: item.metadata.category,
                coordinate_id: item.metadata.coordinate_id,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        }

        return .success(BulkItemRegistrationResponse(
            status: "success",
            total_count: items.count,
            success_count: items.count,
            failed_count: 0,
            items: registeredItems,
            errors: []
        ))
    }
}
