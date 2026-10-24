//
//  PartnerProfileClient.swift
//  irodori
//
//  相棒画面 (案E) の API クライアント。
//  GET  api/partner/profile             ミッション制の理解度・ミッション・相棒の発見・今週のふりかえり
//  POST api/partner/discoveries/answer  相棒の発見への返事 (相棒の返しと、数え直した理解度が返る)
//

import Foundation

// MARK: - Response

struct PartnerProfileResponse: Codable, Hashable {
    let status: String
    let understanding: PartnerUnderstanding
    let missions: [PartnerProfileMission]
    var discoveries: [PartnerProfileDiscovery]
    let weekly: PartnerWeekly?
    /// あなたに似合う色の組み合わせ (手持ちですぐできる → いいねから → ちょっと冒険)
    var color_combos: [PartnerColorCombo]? = nil
}

struct PartnerColorCombo: Codable, Hashable, Identifiable {
    struct ComboColor: Codable, Hashable {
        let key: String
        let name: String
        let hex: String
        let ratio: Double
        let owned: Bool
    }

    struct ComboItem: Codable, Hashable, Identifiable {
        let id: String
        let label: String
        let image_url: String
    }

    let id: String
    let name: String
    let why: String
    let tag: String
    /// ready | liked | try
    let kind: String
    let colors: [ComboColor]
    let items: [ComboItem]
    let hint: String?
    /// 「この配色で組む」で主役にする手持ちの服
    let pivot_item_id: String?
}

struct PartnerUnderstanding: Codable, Hashable {
    struct Stage: Codable, Hashable {
        let index: Int
        let name: String
        let at_pct: Int
        let unlock: String
    }

    let pct: Int
    let stage: Stage
    let next_stage: Stage?
    let stages: [Stage]
    let cleared: Int
    let total: Int
}

struct PartnerProfileMission: Codable, Hashable, Identifiable {
    let id: String
    let stage: Int
    let title: String
    let hint: String
    let points: Int
    let current: Int
    let target: Int
    let done: Bool
    /// open_home / open_closet / open_camera / open_calendar / open_onboarding / check_discoveries
    let action: String
    let icon: String
}

struct PartnerProfileDiscovery: Codable, Hashable, Identifiable {
    let id: String
    let hue: String
    let rarity: String          // normal | surprise | rare
    let icon: String
    /// new | answered | locked
    var status: String
    let hint: String?           // locked のときの条件
    let date: String?
    let date_label: String?
    let headline: String?
    let short: String?
    let body: String?
    let viz: PartnerDiscoveryViz?
    var dig: PartnerDiscoveryDig?

    var isLocked: Bool { status == "locked" }
    var isWaiting: Bool { !isLocked && dig?.answer == nil }

    var rarityLabel: String? {
        switch rarity {
        case "rare": return "レア"
        case "surprise": return "意外"
        default: return nil
        }
    }
}

struct PartnerDiscoveryViz: Codable, Hashable {
    /// bars | colors | items
    let type: String
    let labels: [String]
    let values: [Double]?
    let unit: String?
    let highlight: Int?
    let colors: [String]?
    let image_urls: [String]?
}

struct PartnerDiscoveryDig: Codable, Hashable {
    let question: String?
    let options: [String]
    var answer: String?
    var reply: String?
}

struct PartnerWeekly: Codable, Hashable {
    struct Number: Codable, Hashable {
        let label: String
        let value: Int
        let unit: String
        let body: String
    }

    let range: String
    let discovery_ids: [String]
    let count: Int
    let number: Number
}

struct PartnerDiscoveryAnswerResponse: Codable, Hashable {
    let status: String
    let discovery_id: String
    let answer: String
    let reply: String
    let understanding: PartnerUnderstanding
    let missions: [PartnerProfileMission]
}

// MARK: - Client

protocol PartnerProfileClientProtocol {
    func get(uid: String) async throws -> Result<PartnerProfileResponse, HTTPError>
    func answer(uid: String, discoveryId: String, answer: String) async throws -> Result<PartnerDiscoveryAnswerResponse, HTTPError>
}

final class PartnerProfileClient: PartnerProfileClientProtocol {
    private let baseURL: String

    init(baseURL: String = PartnerProfileClient.defaultBaseURL) {
        self.baseURL = baseURL
    }

    /// 本番。DEBUG ビルドだけ、起動時の環境変数 IRODORI_API_BASE でローカルの API に向けられる
    static var defaultBaseURL: String {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["IRODORI_API_BASE"], !v.isEmpty { return v }
        #endif
        return OwnedFirstHomeClient.productionBaseURL
    }

    private struct AnswerBody: Encodable {
        let user_id: String
        let discovery_id: String
        let answer: String
    }

    func get(uid: String) async throws -> Result<PartnerProfileResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/partner/profile")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        return try await send(URLRequest(url: url))
    }

    func answer(uid: String, discoveryId: String, answer: String) async throws -> Result<PartnerDiscoveryAnswerResponse, HTTPError> {
        guard let url = URL(string: "\(baseURL)/api/partner/discoveries/answer") else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(AnswerBody(user_id: uid, discovery_id: discoveryId, answer: answer))
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
                print("[PartnerProfileClient] decode error: \(error)")
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
