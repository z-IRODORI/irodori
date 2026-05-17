//
//  CoordinateDetailClient.swift
//  irodori
//
//  coordinate_id をキーに 1件のコーディネート詳細を取得する.
//

import Foundation

protocol CoordinateDetailClientProtocol {
    func get(coordinateId: String) async throws -> Result<CoordinateDetailResponse, Error>
}

final class CoordinateDetailClient: CoordinateDetailClientProtocol {
    func get(coordinateId: String) async throws -> Result<CoordinateDetailResponse, Error> {
        let baseURL = "https://irodori-api.onrender.com"
        guard let encoded = coordinateId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return .failure(URLError(.badURL))
        }
        let url = URL(string: "\(baseURL)/api/coordinate/\(encoded)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(URLError(.init(rawValue: httpResponse.statusCode)))
            }
            let response = try JSONDecoder().decode(CoordinateDetailResponse.self, from: data)
            return .success(response)
        } catch {
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}
