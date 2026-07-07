//
//  CalendarOutfitClient.swift
//  irodori
//
//  予定コーデ (カレンダーストック) APIクライアント。
//  着用実績 (worn) とは別の users/{uid}/calendar_outfits 名前空間を操作する。
//

import Foundation

struct CalendarOutfit: Codable, Identifiable, Hashable {
    let date: String        // YYYY-MM-DD
    let kind: String        // pool | self
    let target_id: String   // pool_id または coordinate id
    let image_url: String
    let source: String
    var id: String { date }
}

struct CalendarOutfitsResponse: Codable {
    let status: String
    let items: [CalendarOutfit]
}

struct CalendarOutfitPutResponse: Codable {
    let status: String
    let item: CalendarOutfit?
}

struct CalendarOutfitDeleteResponse: Codable {
    let status: String
}

struct CalendarOutfitBulkResponse: Codable {
    let status: String
    let saved_count: Int
    let skipped: [String]
}

protocol CalendarOutfitClientProtocol {
    func list(uid: String, year: Int, month: Int) async throws -> Result<CalendarOutfitsResponse, HTTPError>
    func put(uid: String, date: String, kind: String, targetId: String, imageURL: String, source: String) async throws -> Result<CalendarOutfitPutResponse, HTTPError>
    func delete(uid: String, date: String) async throws -> Result<CalendarOutfitDeleteResponse, HTTPError>
    func bulk(uid: String, items: [CalendarOutfit], overwrite: Bool) async throws -> Result<CalendarOutfitBulkResponse, HTTPError>
}

final class CalendarOutfitClient: CalendarOutfitClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct PutRequestBody: Encodable {
        let kind: String
        let target_id: String
        let image_url: String
        let source: String
    }

    private struct BulkRequestBody: Encodable {
        let items: [CalendarOutfit]
        let overwrite: Bool
    }

    func list(uid: String, year: Int, month: Int) async throws -> Result<CalendarOutfitsResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/calendar/outfits")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month)),
        ]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    func put(uid: String, date: String, kind: String, targetId: String, imageURL: String, source: String) async throws -> Result<CalendarOutfitPutResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/calendar/outfits/\(date)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(
            PutRequestBody(kind: kind, target_id: targetId, image_url: imageURL, source: source)
        )
        return try await send(request)
    }

    func delete(uid: String, date: String) async throws -> Result<CalendarOutfitDeleteResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/calendar/outfits/\(date)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    func bulk(uid: String, items: [CalendarOutfit], overwrite: Bool) async throws -> Result<CalendarOutfitBulkResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/calendar/outfits/bulk")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(BulkRequestBody(items: items, overwrite: overwrite))
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> Result<T, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(T.self, from: data))
            } catch {
                print("[CalendarOutfitClient] decode error: \(error)")
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

final class MockCalendarOutfitClient: CalendarOutfitClientProtocol {
    func list(uid: String, year: Int, month: Int) async throws -> Result<CalendarOutfitsResponse, HTTPError> {
        .success(.init(status: "success", items: []))
    }

    func put(uid: String, date: String, kind: String, targetId: String, imageURL: String, source: String) async throws -> Result<CalendarOutfitPutResponse, HTTPError> {
        .success(.init(
            status: "success",
            item: CalendarOutfit(date: date, kind: kind, target_id: targetId, image_url: imageURL, source: source)
        ))
    }

    func delete(uid: String, date: String) async throws -> Result<CalendarOutfitDeleteResponse, HTTPError> {
        .success(.init(status: "success"))
    }

    func bulk(uid: String, items: [CalendarOutfit], overwrite: Bool) async throws -> Result<CalendarOutfitBulkResponse, HTTPError> {
        .success(.init(status: "success", saved_count: items.count, skipped: []))
    }
}
