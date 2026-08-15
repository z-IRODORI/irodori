//
//  PhoneLinkClient.swift
//  irodori
//
//  電話番号 (Firebase Auth uid) とアプリ内 user_id の紐付けAPI。
//  旧バージョンで電話番号なしで登録したユーザー (端末生成UUIDのuserId) が
//  電話番号認証したとき、その対応をサーバに記録し (link)、
//  機種変更/再インストール時に電話番号ログインから旧 user_id を復元する (linkedAccount)。
//  なりすまし防止のため Firebase ID トークンを Authorization ヘッダで送る (DeleteUserClient と同じ方式)。
//

import Foundation

struct PhoneLinkResponse: Decodable {
    let status: String     // "linked"
    let user_id: String
}

struct LinkedAccountResponse: Decodable {
    let status: String     // "success"
    let user_id: String
}

protocol PhoneLinkClientProtocol {
    func link(userId: String, idToken: String) async throws -> Result<PhoneLinkResponse, HTTPError>
    func linkedAccount(idToken: String) async throws -> Result<LinkedAccountResponse, HTTPError>
}

final class PhoneLinkClient: PhoneLinkClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func link(userId: String, idToken: String) async throws -> Result<PhoneLinkResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/user/link-phone")!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60   // Render のコールドスタートを考慮
        return await send(request)
    }

    func linkedAccount(idToken: String) async throws -> Result<LinkedAccountResponse, HTTPError> {
        guard let url = URL(string: "\(baseURL)/api/user/linked-account") else {
            return .failure(.responseError)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        return await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async -> Result<T, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(T.self, from: data))
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockPhoneLinkClient: PhoneLinkClientProtocol {
    var linkedUserId: String? = nil

    func link(userId: String, idToken: String) async throws -> Result<PhoneLinkResponse, HTTPError> {
        .success(.init(status: "linked", user_id: userId))
    }

    func linkedAccount(idToken: String) async throws -> Result<LinkedAccountResponse, HTTPError> {
        guard let linkedUserId else { return .failure(.responseError) }
        return .success(.init(status: "success", user_id: linkedUserId))
    }
}
