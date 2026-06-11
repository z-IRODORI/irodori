//
//  OutfitCollageClient.swift
//  irodori
//
//  コーデコラージュ (クローゼットでコーデ) APIクライアント
//  - get:        本日のコラージュ取得 (当日キャッシュがあれば即時)
//  - regenerate: アイテム差し替え / シャッフル再生成
//

import Foundation

protocol OutfitCollageClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<OutfitCollageResponse, HTTPError>
    func regenerate(
        uid: String,
        gender: Gender,
        itemIds: [String: String],
        excludeItemIds: [String]
    ) async throws -> Result<OutfitCollageResponse, HTTPError>
}

struct OutfitCollageGenerateRequest: Encodable {
    let gender: String
    let item_ids: [String: String]       // slot -> closet item id (ピン留め)
    let exclude_item_ids: [String]       // シャッフル時に避けるアイテム
}

final class OutfitCollageClient: OutfitCollageClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func get(uid: String, gender: Gender) async throws -> Result<OutfitCollageResponse, HTTPError> {
        let endpoint = "api/home/outfit-collage"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "gender", value: gender.apiValue),
        ]
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // 初回は画像合成があるため長め

        return try await send(request)
    }

    func regenerate(
        uid: String,
        gender: Gender,
        itemIds: [String: String],
        excludeItemIds: [String]
    ) async throws -> Result<OutfitCollageResponse, HTTPError> {
        let endpoint = "api/outfit-collage"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body = OutfitCollageGenerateRequest(
            gender: gender.apiValue,
            item_ids: itemIds,
            exclude_item_ids: excludeItemIds
        )
        request.httpBody = try? JSONEncoder().encode(body)

        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Result<OutfitCollageResponse, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(OutfitCollageResponse.self, from: data)
                return .success(response)
            } catch {
                print("[OutfitCollageClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockOutfitCollageClient: OutfitCollageClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<OutfitCollageResponse, HTTPError> {
        return .success(.mock())
    }

    func regenerate(
        uid: String,
        gender: Gender,
        itemIds: [String: String],
        excludeItemIds: [String]
    ) async throws -> Result<OutfitCollageResponse, HTTPError> {
        return .success(.mock())
    }
}
