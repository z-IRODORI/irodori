//
//  DeviceClient.swift
//  irodori
//
//  玄関カメラ (Raspberry Pi + AI Camera) の連携 API (/api/devices/*)。
//  デバイスは user_id を持たず、ペアリングでアカウントに登録される。
//  なりすまし防止のため Firebase ID トークンを Authorization ヘッダで送る (PhoneLinkClient と同じ方式)。
//  設計: z-IRODORI/proposals/raspi-aicam-outfit-capture.md §3〜§4
//

import UIKit

// MARK: - レスポンス

struct DeviceClaimResponse: Decodable {
    let claim_token: String
    let expires_in: Int
    /// QR に載せる文字列 ({"irodori":1,"claim":"…"})。ラズパイのカメラがこれを読む
    let qr_payload: String
}

struct DeviceSettings: Codable, Equatable {
    var window_start_hour: Int
    var window_end_hour: Int
    var one_per_day: Bool
    /// 撮影後、次の自動撮影までの最短秒数 (連写防止)
    var capture_cooldown_s: Int
    var rotation: Int
    /// 記録できたらプッシュ通知する
    var notify_on_capture: Bool

    init(window_start_hour: Int, window_end_hour: Int, one_per_day: Bool,
         capture_cooldown_s: Int = 120, rotation: Int, notify_on_capture: Bool = true) {
        self.window_start_hour = window_start_hour
        self.window_end_hour = window_end_hour
        self.one_per_day = one_per_day
        self.capture_cooldown_s = capture_cooldown_s
        self.rotation = rotation
        self.notify_on_capture = notify_on_capture
    }

    // 旧サーバの応答 (フィールド無し) でも落ちないように既定値で補う
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        window_start_hour = try c.decode(Int.self, forKey: .window_start_hour)
        window_end_hour = try c.decode(Int.self, forKey: .window_end_hour)
        one_per_day = try c.decodeIfPresent(Bool.self, forKey: .one_per_day) ?? false
        capture_cooldown_s = try c.decodeIfPresent(Int.self, forKey: .capture_cooldown_s) ?? 120
        rotation = try c.decodeIfPresent(Int.self, forKey: .rotation) ?? 90
        notify_on_capture = try c.decodeIfPresent(Bool.self, forKey: .notify_on_capture) ?? true
    }
}

struct DeviceJudgement: Decodable, Equatable {
    let present: Bool?
    let ok: Bool?
    let hints: [String]?
}

struct DeviceStatus: Decodable, Equatable {
    let state: String?
    let judgement: DeviceJudgement?
    let updated_at: Double?
}

struct DeviceCaptureSummary: Decodable, Equatable {
    let capture_id: String?
    let status: String?         // processing | completed | canceled | failed
    let job_id: String?
    let coordinate_id: String?
    let error: String?
    let selected_index: Int?
    let captured_at: Double?
    let trigger: String?        // auto | test
    let thumbnails: [String?]?
}

struct DeviceInfo: Decodable, Equatable, Identifiable {
    let device_id: String
    let model: String?
    let fw_version: String?
    let online: Bool
    let last_seen_at: Double?
    let settings: DeviceSettings
    let status: DeviceStatus?
    let setup_mode: Bool
    let preview_url: String?
    let preview_at: Double?
    let last_capture: DeviceCaptureSummary?

    var id: String { device_id }
}

struct DeviceListResponse: Decodable {
    let devices: [DeviceInfo]
}

struct DeviceCommandResponse: Decodable {
    let status: String
    let command: String
}

struct DeviceUnlinkResponse: Decodable {
    let status: String
    let device_id: String
}

/// 未ペアリングで QR 待ちのデバイス (同じネットワークから見えたもの)
struct DevicePresence: Decodable, Equatable {
    let device_id_suffix: String
    let state: String        // pairing | reading | registering | paired
    let model: String?
    let seen_ago_s: Double
}

struct DevicePresenceResponse: Decodable {
    let devices: [DevicePresence]
    let client_ip_known: Bool
}

enum DeviceCommand: String {
    case testCapture = "test_capture"
    case setupOn = "setup_on"
    case setupOff = "setup_off"
}

// MARK: - プロトコル

protocol DeviceClientProtocol {
    func createClaim(userId: String, idToken: String) async throws -> Result<DeviceClaimResponse, HTTPError>
    func listDevices(userId: String, idToken: String) async throws -> Result<DeviceListResponse, HTTPError>
    func getDevice(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError>
    func sendCommand(deviceId: String, command: DeviceCommand, userId: String, idToken: String) async throws -> Result<DeviceCommandResponse, HTTPError>
    func updateSettings(deviceId: String, settings: DeviceSettings, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError>
    func unlink(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceUnlinkResponse, HTTPError>
    /// ライブプレビューのロングポーリング。seq より新しいフレームが来るまで最大 wait 秒待って返す。
    /// 新フレームが無ければ nil (204)。
    func fetchPreview(deviceId: String, after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)?
    /// 同じネットワークで QR 待ちのデバイス一覧 (ペアリング画面の起動確認用)
    func getPresence(userId: String, idToken: String) async throws -> Result<DevicePresenceResponse, HTTPError>
    /// ペアリング前のカメラ映像 (同じネットワークの QR 待ちデバイス)。ロングポーリング
    func fetchPresencePreview(after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)?
}

// MARK: - 実装

final class DeviceClient: DeviceClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct CommandBody: Encodable { let type: String }

    func createClaim(userId: String, idToken: String) async throws -> Result<DeviceClaimResponse, HTTPError> {
        await send(request(method: "POST", path: "api/devices/claims", userId: userId, idToken: idToken))
    }

    func listDevices(userId: String, idToken: String) async throws -> Result<DeviceListResponse, HTTPError> {
        await send(request(method: "GET", path: "api/devices", userId: userId, idToken: idToken))
    }

    func getDevice(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError> {
        await send(request(method: "GET", path: "api/devices/\(deviceId)", userId: userId, idToken: idToken))
    }

    func sendCommand(deviceId: String, command: DeviceCommand, userId: String, idToken: String) async throws -> Result<DeviceCommandResponse, HTTPError> {
        var req = request(method: "POST", path: "api/devices/\(deviceId)/commands", userId: userId, idToken: idToken)
        req.httpBody = try JSONEncoder().encode(CommandBody(type: command.rawValue))
        return await send(req)
    }

    func updateSettings(deviceId: String, settings: DeviceSettings, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError> {
        var req = request(method: "PATCH", path: "api/devices/\(deviceId)/settings", userId: userId, idToken: idToken)
        req.httpBody = try JSONEncoder().encode(settings)
        return await send(req)
    }

    func unlink(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceUnlinkResponse, HTTPError> {
        await send(request(method: "DELETE", path: "api/devices/\(deviceId)", userId: userId, idToken: idToken))
    }

    func getPresence(userId: String, idToken: String) async throws -> Result<DevicePresenceResponse, HTTPError> {
        await send(request(method: "GET", path: "api/devices/presence", userId: userId, idToken: idToken))
    }

    func fetchPresencePreview(after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)? {
        try await fetchJPEG(path: "api/devices/presence/preview", after: seq, wait: wait, userId: userId, idToken: idToken)
    }

    func fetchPreview(deviceId: String, after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)? {
        try await fetchJPEG(path: "api/devices/\(deviceId)/preview", after: seq, wait: wait, userId: userId, idToken: idToken)
    }

    private func fetchJPEG(path: String, after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)? {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "after", value: String(seq)),
            URLQueryItem(name: "wait", value: String(wait)),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "GET"
        req.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = wait + 15
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 204 { return nil }
        guard http.statusCode == 200, let image = UIImage(data: data) else {
            throw HTTPError.fromStatusCode(http.statusCode)
        }
        let newSeq = Int(http.value(forHTTPHeaderField: "X-Preview-Seq") ?? "") ?? seq
        return (image, newSeq)
    }

    // MARK: - 共通

    private func request(method: String, path: String, userId: String, idToken: String) -> URLRequest {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60   // Render のコールドスタートを考慮
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest) async -> Result<T, HTTPError> {
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
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockDeviceClient: DeviceClientProtocol {
    var devices: [DeviceInfo] = []

    static func sampleDevice(online: Bool = true, setupMode: Bool = false) -> DeviceInfo {
        DeviceInfo(
            device_id: "104A50500A2901033364013000000000",
            model: "rpi4+imx500",
            fw_version: "0.1.0",
            online: online,
            last_seen_at: Date().timeIntervalSince1970,
            settings: DeviceSettings(window_start_hour: 6, window_end_hour: 11, one_per_day: true, rotation: 90),
            status: DeviceStatus(state: "framing",
                                 judgement: DeviceJudgement(present: true, ok: false, hints: ["一歩下がって"]),
                                 updated_at: Date().timeIntervalSince1970),
            setup_mode: setupMode,
            preview_url: nil,
            preview_at: nil,
            last_capture: nil
        )
    }

    func createClaim(userId: String, idToken: String) async throws -> Result<DeviceClaimResponse, HTTPError> {
        .success(.init(claim_token: "mock", expires_in: 600, qr_payload: "{\"irodori\":1,\"claim\":\"mock\"}"))
    }

    func listDevices(userId: String, idToken: String) async throws -> Result<DeviceListResponse, HTTPError> {
        .success(.init(devices: devices))
    }

    func getDevice(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError> {
        guard let d = devices.first(where: { $0.device_id == deviceId }) else { return .failure(.notFound) }
        return .success(d)
    }

    func sendCommand(deviceId: String, command: DeviceCommand, userId: String, idToken: String) async throws -> Result<DeviceCommandResponse, HTTPError> {
        .success(.init(status: "queued", command: command.rawValue))
    }

    func updateSettings(deviceId: String, settings: DeviceSettings, userId: String, idToken: String) async throws -> Result<DeviceInfo, HTTPError> {
        guard let d = devices.first(where: { $0.device_id == deviceId }) else { return .failure(.notFound) }
        return .success(d)
    }

    func unlink(deviceId: String, userId: String, idToken: String) async throws -> Result<DeviceUnlinkResponse, HTTPError> {
        devices.removeAll { $0.device_id == deviceId }
        return .success(.init(status: "unlinked", device_id: deviceId))
    }

    func fetchPreview(deviceId: String, after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)? {
        try? await Task.sleep(for: .seconds(wait))
        return nil
    }

    var presence: [DevicePresence] = []
    func getPresence(userId: String, idToken: String) async throws -> Result<DevicePresenceResponse, HTTPError> {
        .success(.init(devices: presence, client_ip_known: true))
    }

    func fetchPresencePreview(after seq: Int, wait: Double, userId: String, idToken: String) async throws -> (image: UIImage, seq: Int)? {
        try? await Task.sleep(for: .seconds(wait))
        return nil
    }
}
