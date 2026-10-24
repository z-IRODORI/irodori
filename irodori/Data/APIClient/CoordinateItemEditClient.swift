//
//  CoordinateItemEditClient.swift
//  irodori
//
//  コーデの着用アイテムを直す (解析の検出が違っていたとき)。
//  PUT    api/coordinate/{id}/items/{item_id}       クローゼットの服に差し替える
//  DELETE api/coordinate/{id}/items/{item_id}?uid=  コーデから外す (クローゼットの服は消さない)
//  どちらも更新後のコーデ詳細を返す。
//

import Foundation

extension Notification.Name {
    /// コーデやアイテムを消した・直したとき (カレンダー・ホームの一覧を取り直す)
    static let coordinateDidChange = Notification.Name("irodori.coordinateDidChange")
    static let closetDidChange = Notification.Name("irodori.closetDidChange")
}

protocol CoordinateItemEditClientProtocol {
    func replace(uid: String, coordinateId: String, itemId: String, closetItemId: String) async throws -> Result<CoordinateDetailResponse, HTTPError>
    func remove(uid: String, coordinateId: String, itemId: String) async throws -> Result<CoordinateDetailResponse, HTTPError>
}

final class CoordinateItemEditClient: CoordinateItemEditClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct ReplaceBody: Encodable {
        let uid: String
        let closet_item_id: String
    }

    func replace(uid: String, coordinateId: String, itemId: String, closetItemId: String) async throws -> Result<CoordinateDetailResponse, HTTPError> {
        guard let url = URL(string: "\(baseURL)/api/coordinate/\(coordinateId)/items/\(itemId)") else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(ReplaceBody(uid: uid, closet_item_id: closetItemId))
        return try await send(request)
    }

    func remove(uid: String, coordinateId: String, itemId: String) async throws -> Result<CoordinateDetailResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/coordinate/\(coordinateId)/items/\(itemId)")!
        components.queryItems = [URLQueryItem(name: "uid", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> Result<T, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let http = urlResponse as? HTTPURLResponse, http.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(http.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(T.self, from: data))
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            if let e = error as? URLError, e.code == .cancelled { throw CancellationError() }
            return .failure(.responseError)
        }
    }
}
