//
//  UpdateUserPrefectureClient.swift
//  irodori
//
//  PUT /api/user/profile/prefecture を呼び、ユーザーの居住地を Firestore に永続化する.
//

import Foundation

struct UpdateUserPrefectureRequest: Encodable {
    let prefecture_code: String
}

struct UpdateUserPrefectureResponse: Decodable {
    let status: String
    let prefecture_code: String
}

protocol UpdateUserPrefectureClientProtocol {
    func put(uid: String, prefectureCode: String) async throws -> Result<UpdateUserPrefectureResponse, HTTPError>
}

final class UpdateUserPrefectureClient: UpdateUserPrefectureClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func put(uid: String, prefectureCode: String) async throws -> Result<UpdateUserPrefectureResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/user/profile/prefecture")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else {
            return .failure(.responseError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            UpdateUserPrefectureRequest(prefecture_code: prefectureCode)
        )

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse,
               httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(UpdateUserPrefectureResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}
