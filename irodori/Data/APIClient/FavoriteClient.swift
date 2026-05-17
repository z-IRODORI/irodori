//
//  FavoriteClient.swift
//  irodori
//
//  /api/favorites の REST クライアント (GET/POST/DELETE).
//

import Foundation

struct FavoriteListResponse: Decodable {
    let favorites: [Favorite]
}

struct AddFavoriteRequest: Encodable {
    let kind: String
    let target_id: String
    let image_url: String?
    let date: String?
}

struct AddFavoriteResponse: Decodable {
    let status: String
    let fav_id: String
}

protocol FavoriteClientProtocol {
    func list(uid: String, kind: FavoriteKind?) async throws -> Result<[Favorite], HTTPError>
    func add(uid: String, kind: FavoriteKind, targetId: String, imageURL: String?, date: String?) async throws -> Result<String, HTTPError>
    func remove(uid: String, favId: String) async throws -> Result<Bool, HTTPError>
}

final class FavoriteClient: FavoriteClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func list(uid: String, kind: FavoriteKind? = nil) async throws -> Result<[Favorite], HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/favorites")!
        var items: [URLQueryItem] = [URLQueryItem(name: "user_id", value: uid)]
        if let kind { items.append(URLQueryItem(name: "kind", value: kind.rawValue)) }
        components.queryItems = items
        guard let url = components.url else { return .failure(.responseError) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(FavoriteListResponse.self, from: data)
                return .success(response.favorites)
            } catch {
                print("[FavoriteClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }

    func add(uid: String, kind: FavoriteKind, targetId: String, imageURL: String?, date: String?) async throws -> Result<String, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/favorites")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AddFavoriteRequest(kind: kind.rawValue, target_id: targetId, image_url: imageURL, date: date)
        )

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(AddFavoriteResponse.self, from: data)
                return .success(response.fav_id)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }

    func remove(uid: String, favId: String) async throws -> Result<Bool, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/favorites/\(favId)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            return .success(true)
        } catch {
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock
final class MockFavoriteClient: FavoriteClientProtocol {
    func list(uid: String, kind: FavoriteKind?) async throws -> Result<[Favorite], HTTPError> { .success([]) }
    func add(uid: String, kind: FavoriteKind, targetId: String, imageURL: String?, date: String?) async throws -> Result<String, HTTPError> {
        .success(Favorite.favId(kind: kind, targetId: targetId))
    }
    func remove(uid: String, favId: String) async throws -> Result<Bool, HTTPError> { .success(true) }
}
