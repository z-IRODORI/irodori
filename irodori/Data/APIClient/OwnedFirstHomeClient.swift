//
//  OwnedFirstHomeClient.swift
//  irodori
//
//  手持ち起点ホーム (リニューアル版) の API クライアント。
//  GET  api/home/owned-first           手持ちの組み合わせ3案 + 近い着こなしお手本 + 相棒のひとこと
//  POST api/home/owned-first/wear      「今日着る」(カレンダー + 行動ログ)
//  POST api/home/owned-first/feedback  3案の見送り理由
//

import Foundation

// MARK: - Response

struct OwnedFirstItem: Codable, Hashable, Identifiable {
    let item_id: String
    let slot: String          // tops | bottoms | outer | shoes
    let label: String         // 「ホワイト シャツ」(色 + カテゴリの一般名詞)
    let image_url: String
    let family: String
    let fit: String?          // ok | marginal | ng (気温への適合度)

    var id: String { item_id }
}

struct OwnedFirstMissingItem: Codable, Hashable, Identifiable {
    let slot: String
    let label: String
    let family: String
    let fit: String?
    /// 同じ種類のアイテムカタログ画像 (コーデモデルが無い案の定番などに付く)
    let image_url: String?

    var id: String { "\(slot)_\(label)" }
}

struct OwnedFirstExample: Codable, Hashable {
    let pool_id: String?
    let image_url: String?
    let vibe: String?
    let match_score: Double?
    let extraction: OwnedFirstExtraction?
}

/// コーデモデルが着ているアイテム (サーバのアイテムカタログ)。status: none | pending | ready
/// (旧形式の cropped / failed も受け付ける)
struct OwnedFirstExtraction: Codable, Hashable {
    let status: String
    let items: [OwnedFirstExtractedItem]

    var isInProgress: Bool { status == "pending" || status == "cropped" }
}

struct OwnedFirstExtractedItem: Codable, Hashable, Identifiable {
    let slot: String
    let label: String
    let crop_url: String
    let image_url: String
    let owned_item_id: String?
    let owned_image_url: String?

    var id: String { "\(slot)_\(label)_\(crop_url)" }
    /// 商品風画像ができていればそれ、まだなら写真の切り抜き
    var displayURL: String { image_url.isEmpty ? crop_url : image_url }
}

/// 対象日の気候と服装の目安 (サーバの climate_logic)
struct OwnedFirstClimate: Codable, Hashable {
    let band: String
    let label: String
    let guidance: String
    let outer_policy: String   // none | optional | required
    let max_temp: Int
    let min_temp: Int
}

struct OwnedFirstRecipe: Codable, Hashable, Identifiable {
    let recipe_id: String
    let kind: String          // owned | partial | zero | discovery
    let status_label: String
    let pair_text: String
    let main_family: String
    let hero_item_id: String?
    let owned_items: [OwnedFirstItem]
    let missing_items: [OwnedFirstMissingItem]
    let example: OwnedFirstExample?
    let reason: String
    /// カードの見出し (目を引く短いコピー)。古いサーバでは nil
    let title: String?
    let climate_warnings: [String]?

    var id: String { recipe_id }
    var displayTitle: String { (title?.isEmpty == false ? title : nil) ?? status_label }
    var isDiscovery: Bool { kind == "discovery" }
}

struct OwnedFirstWeather: Codable, Hashable {
    let min_temp: Int
    let max_temp: Int
    let condition: String
    let area_code: String?
    let diff_from_yesterday: Int?
}

/// 相棒のひとことが触れた「覚えていること」(サーバで実在を確認済み)
struct OwnedFirstMemory: Codable, Hashable {
    let id: String
    let kind: String     // dislike | worn | favorite | new | sleeping | chat | answer | vote
    let label: String    // 「10/21『色が好みじゃない』で見送り」
}

struct OwnedFirstHomeResponse: Codable, Hashable {
    let target_date: String
    let weather: OwnedFirstWeather
    let daily_angle: String
    let daily_angle_label: String
    let climate: OwnedFirstClimate?
    let greeting: String
    let data_nudge: String?
    let speaking_style: String
    let tone: String
    let partner_type_name: String
    let closet_count: Int
    let hero_item_id: String?
    let pivot_item_id: String?
    let decided_recipe_id: String?
    let text_source: String   // gemini | template
    let memory: OwnedFirstMemory?
    let recipes: [OwnedFirstRecipe]
    let closet_items: [OwnedFirstItem]
}

struct OwnedFirstWearResponse: Codable {
    let status: String
    let target_date: String
    let recipe_id: String
    let sendoff_message: String
    let learned_summary: String
}

struct OwnedFirstExamplesResponse: Codable {
    let status: String
    let examples: [String: OwnedFirstExtraction]
}

struct OwnedFirstFeedbackResponse: Codable {
    let status: String
    let ack_message: String
    let learned_summary: String
}

// MARK: - Client

protocol OwnedFirstHomeClientProtocol {
    func get(uid: String, gender: String, targetDate: String, pivotItemId: String?) async throws -> Result<OwnedFirstHomeResponse, HTTPError>
    func wear(uid: String, recipe: OwnedFirstRecipe, targetDate: String, maxTemp: Int?) async throws -> Result<OwnedFirstWearResponse, HTTPError>
    /// reason: like (案ごとのいいね) | cold | color | style | mood (見送り)。recipes が1件なら案ごと
    func feedback(uid: String, targetDate: String, reason: String, recipes: [OwnedFirstRecipe]) async throws -> Result<OwnedFirstFeedbackResponse, HTTPError>
    func examples(uid: String, poolIds: [String]) async throws -> Result<OwnedFirstExamplesResponse, HTTPError>
}

final class OwnedFirstHomeClient: OwnedFirstHomeClientProtocol {
    static let productionBaseURL = "https://irodori-api.onrender.com"

    private let baseURL: String

    init(baseURL: String = OwnedFirstHomeClient.productionBaseURL) {
        self.baseURL = baseURL
    }

    private struct WearBody: Encodable {
        let target_date: String
        let recipe_id: String
        let item_ids: [String]
        let missing_labels: [String]
        let image_url: String
        let is_discovery: Bool
        let pair_text: String
        let max_temp: Int?
    }

    private struct FeedbackBody: Encodable {
        let target_date: String
        let reason: String
        let recipe_ids: [String]
        let families: [String]
        /// 案ごとのフィードバックのとき、相棒が覚えておく案の名前と服
        let title: String
        let item_ids: [String]
    }

    func get(uid: String, gender: String, targetDate: String, pivotItemId: String?) async throws -> Result<OwnedFirstHomeResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/home/owned-first")!
        var query = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "gender", value: gender),
            URLQueryItem(name: "target_date", value: targetDate),
        ]
        if let code = UserDefaults.standard.string(forKey: UserDefaultsKey.prefectureCode.rawValue), !code.isEmpty {
            query.append(URLQueryItem(name: "prefecture_code", value: code))
        }
        if let pivotItemId {
            query.append(URLQueryItem(name: "pivot_item_id", value: pivotItemId))
        }
        components.queryItems = query
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Gemini 生成 + Render のコールドスタートを考慮して長めに待つ
        request.timeoutInterval = 60
        return try await send(request)
    }

    func wear(uid: String, recipe: OwnedFirstRecipe, targetDate: String, maxTemp: Int?) async throws -> Result<OwnedFirstWearResponse, HTTPError> {
        let body = WearBody(
            target_date: targetDate,
            recipe_id: recipe.recipe_id,
            item_ids: recipe.owned_items.map(\.item_id),
            missing_labels: recipe.missing_items.map(\.label),
            image_url: recipe.example?.image_url ?? recipe.owned_items.first?.image_url ?? "",
            is_discovery: recipe.isDiscovery,
            pair_text: recipe.pair_text,
            max_temp: maxTemp
        )
        return try await post(path: "api/home/owned-first/wear", uid: uid, body: body)
    }

    /// reason: like (案ごとのいいね) | cold | color | style | mood (見送り)。recipes が1件なら案ごと
    func feedback(uid: String, targetDate: String, reason: String, recipes: [OwnedFirstRecipe]) async throws -> Result<OwnedFirstFeedbackResponse, HTTPError> {
        let body = FeedbackBody(
            target_date: targetDate,
            reason: reason,
            recipe_ids: recipes.map(\.recipe_id),
            families: Array(Set(recipes.map(\.main_family))),
            title: recipes.count == 1 ? recipes[0].displayTitle : "",
            item_ids: recipes.count == 1 ? recipes[0].owned_items.map(\.item_id) : []
        )
        return try await post(path: "api/home/owned-first/feedback", uid: uid, body: body)
    }

    func examples(uid: String, poolIds: [String]) async throws -> Result<OwnedFirstExamplesResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/home/owned-first/examples")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: uid),
            URLQueryItem(name: "pool_ids", value: poolIds.joined(separator: ",")),
        ]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<B: Encodable, T: Decodable>(path: String, uid: String, body: B) async throws -> Result<T, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/\(path)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
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
                print("[OwnedFirstHomeClient] decode error: \(error)")
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
