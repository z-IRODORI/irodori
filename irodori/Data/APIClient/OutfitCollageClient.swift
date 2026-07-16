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
        excludeItemIds: [String],
        anchorItemId: String?
    ) async throws -> Result<OutfitCollageResponse, HTTPError>
    /// コーデに合うおすすめ商品 (アフィリエイト導線)。closet-bridge を流用するため重く、遅延ロード用。
    func recommendations(
        uid: String,
        gender: Gender,
        items: [OutfitRecommendItem]
    ) async throws -> Result<ClosetBridgeResponse, HTTPError>
    /// 配置編集用: 透過レイヤー PNG と配置 (正規化 rect + z) を取得
    func getLayout(uid: String, gender: Gender) async throws -> Result<OutfitCollageLayoutResponse, HTTPError>
    /// 編集した配置で再合成して保存。成功時は新しい collage_url を含むレスポンスを返す
    func saveLayout(
        uid: String,
        gender: Gender,
        collageId: String,
        backgroundColor: String,
        items: [OutfitCollageLayoutItem]
    ) async throws -> Result<OutfitCollageResponse, HTTPError>
}

struct OutfitCollageGenerateRequest: Encodable {
    let gender: String
    let item_ids: [String: String]       // slot -> closet item id (ピン留め)
    let exclude_item_ids: [String]       // シャッフル時に避けるアイテム
    let anchor_item_id: String?          // 起点アイテム (item_type からスロットを自動判定してピン留め)
}

struct OutfitRecommendItem: Encodable {
    let category: String
    let color: String
}

struct OutfitRecommendationsRequest: Encodable {
    let gender: String
    let items: [OutfitRecommendItem]
}

struct OutfitCollageLayoutSaveRequest: Encodable {
    struct Item: Encodable {
        let id: String
        let x: Double
        let y: Double
        let w: Double
        let h: Double
        let z: Int
        let r: Double         // 回転 (度, 時計回り)
        let hidden: Bool      // true で合成から除外
    }

    let collage_id: String    // GET layout 時点の collage_id (再生成との競合検出)
    let gender: String
    let background_color: String  // "#RRGGBB"
    let items: [Item]
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
        excludeItemIds: [String],
        anchorItemId: String?
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
            exclude_item_ids: excludeItemIds,
            anchor_item_id: anchorItemId
        )
        request.httpBody = try? JSONEncoder().encode(body)

        return try await send(request)
    }

    func recommendations(
        uid: String,
        gender: Gender,
        items: [OutfitRecommendItem]
    ) async throws -> Result<ClosetBridgeResponse, HTTPError> {
        let endpoint = "api/outfit-collage/recommendations"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // closet-bridge は Gemini+Yahoo で数秒かかる
        let body = OutfitRecommendationsRequest(gender: gender.apiValue, items: items)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(ClosetBridgeResponse.self, from: data)
                return .success(response)
            } catch {
                print("[OutfitCollageClient] recommendations decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }

    func getLayout(uid: String, gender: Gender) async throws -> Result<OutfitCollageLayoutResponse, HTTPError> {
        let endpoint = "api/outfit-collage/layout"
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
        request.timeoutInterval = 60  // 初回はレイヤー生成 (ノックアウト + アップロード) があるため長め

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(OutfitCollageLayoutResponse.self, from: data)
                return .success(response)
            } catch {
                print("[OutfitCollageClient] layout decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }

    func saveLayout(
        uid: String,
        gender: Gender,
        collageId: String,
        backgroundColor: String,
        items: [OutfitCollageLayoutItem]
    ) async throws -> Result<OutfitCollageResponse, HTTPError> {
        let endpoint = "api/outfit-collage/layout"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body = OutfitCollageLayoutSaveRequest(
            collage_id: collageId,
            gender: gender.apiValue,
            background_color: backgroundColor,
            items: items.map {
                .init(id: $0.id, x: $0.x, y: $0.y, w: $0.w, h: $0.h, z: $0.z,
                      r: $0.r, hidden: $0.hidden)
            }
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
        excludeItemIds: [String],
        anchorItemId: String?
    ) async throws -> Result<OutfitCollageResponse, HTTPError> {
        return .success(.mock())
    }

    func recommendations(
        uid: String,
        gender: Gender,
        items: [OutfitRecommendItem]
    ) async throws -> Result<ClosetBridgeResponse, HTTPError> {
        return .success(.mock())
    }

    func getLayout(uid: String, gender: Gender) async throws -> Result<OutfitCollageLayoutResponse, HTTPError> {
        return .success(.mock())
    }

    func saveLayout(
        uid: String,
        gender: Gender,
        collageId: String,
        backgroundColor: String,
        items: [OutfitCollageLayoutItem]
    ) async throws -> Result<OutfitCollageResponse, HTTPError> {
        return .success(.mock())
    }
}
