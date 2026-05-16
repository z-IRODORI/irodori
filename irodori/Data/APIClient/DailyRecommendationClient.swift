//
//  DailyRecommendationClient.swift
//  irodori
//
//  明日のコーデ推薦APIクライアント
//

import Foundation

protocol DailyRecommendationClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<DailyRecommendationResponse, HTTPError>
    func markWorn(uid: String, poolId: String, wornDate: String) async throws -> Result<WearMarkResponse, HTTPError>
}

final class DailyRecommendationClient: DailyRecommendationClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func get(uid: String, gender: Gender) async throws -> Result<DailyRecommendationResponse, HTTPError> {
        let endpoint = "api/home/daily-recommendation"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "gender", value: gender.apiValue),
        ]
        if let prefectureCode = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue),
           !prefectureCode.isEmpty {
            items.append(URLQueryItem(name: "prefecture_code", value: prefectureCode))
        }
        components.queryItems = items
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(DailyRecommendationResponse.self, from: data)
                return .success(response)
            } catch {
                print("[DailyRecommendationClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }

    func markWorn(uid: String, poolId: String, wornDate: String) async throws -> Result<WearMarkResponse, HTTPError> {
        let endpoint = "api/home/daily-recommendation/wear"
        var components = URLComponents(string: "\(baseURL)/\(endpoint)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = WearMarkRequest(pool_id: poolId, worn_date: wornDate)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(WearMarkResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockDailyRecommendationClient: DailyRecommendationClientProtocol {
    func get(uid: String, gender: Gender) async throws -> Result<DailyRecommendationResponse, HTTPError> {
        return .success(.mock())
    }

    func markWorn(uid: String, poolId: String, wornDate: String) async throws -> Result<WearMarkResponse, HTTPError> {
        return .success(.init(status: "ok", pool_id: poolId, worn_date: wornDate))
    }
}
