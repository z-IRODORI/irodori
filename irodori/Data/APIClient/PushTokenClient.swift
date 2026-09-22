//
//  PushTokenClient.swift
//  irodori
//
//  FCM トークンをサーバに登録する (玄関カメラの記録完了通知)。
//  Firebase ID トークンを Bearer で送る (DeviceClient と同じ方式)。
//

import Foundation

protocol PushTokenClientProtocol {
    func register(token: String, userId: String, idToken: String) async throws -> Bool
    func unregister(token: String, userId: String, idToken: String) async throws -> Bool
}

final class PushTokenClient: PushTokenClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct Body: Encodable {
        let token: String
        let platform: String
    }

    func register(token: String, userId: String, idToken: String) async throws -> Bool {
        try await send(method: "POST", token: token, userId: userId, idToken: idToken)
    }

    func unregister(token: String, userId: String, idToken: String) async throws -> Bool {
        try await send(method: "DELETE", token: token, userId: userId, idToken: idToken)
    }

    private func send(method: String, token: String, userId: String, idToken: String) async throws -> Bool {
        var components = URLComponents(string: "\(baseURL)/api/user/push-token")!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(Body(token: token, platform: "ios"))
        req.timeoutInterval = 60
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

final class MockPushTokenClient: PushTokenClientProtocol {
    var registered: [String] = []
    func register(token: String, userId: String, idToken: String) async throws -> Bool {
        registered.append(token); return true
    }
    func unregister(token: String, userId: String, idToken: String) async throws -> Bool {
        registered.removeAll { $0 == token }; return true
    }
}
