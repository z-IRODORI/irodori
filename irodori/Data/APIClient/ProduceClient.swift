//
//  ProduceClient.swift
//  irodori
//
//  相棒のプロデュース (キャラクター → ブランド → アイテム → コーデ) の API。
//  GET  api/produce            ① キャラクター ② ブランド 3 件 ③ おすすめアイテム 3 点 (理由つき)
//  POST api/produce/feedback   アイテムへの いいね / 違う (理由)
//  POST api/produce/owned      「持ってる・買った」→ クローゼットに 1 着登録 (もう持っていれば登録しない)
//  ④ コーデ 3 案は OwnedFirstHomeClient.produceCoordinates (ホームと同じ形)
//

import Foundation

struct ProduceResponse: Codable, Hashable {
    let status: String                    // success | needs_answers | needs_fashion_type
    let character: ProduceCharacter
    let fashion_sense: FashionSense?
    var budget_tier: Double? = nil
    var brands: [ProduceBrand]? = nil
    var selected_brand_id: String? = nil
    var season: [ProduceSeason]? = nil
    var items: [ProduceItem]? = nil
}

struct ProduceCharacter: Codable, Hashable {
    let type_code: String?
    let type_name: String?
    let subtitle: String?
}

struct ProduceBrandImage: Codable, Hashable {
    let path: String?
}

struct ProduceBrandPrice: Codable, Hashable {
    let tier: Int?
    let range_text: String?
}

struct ProduceBrand: Codable, Hashable, Identifiable {
    let id: String
    let name_en: String?
    let name_ja: String?
    let image: ProduceBrandImage?
    let price: ProduceBrandPrice?
    let style_tags_ja: [String]?
    let reasons: [String]?

    var displayName: String { name_ja?.isEmpty == false ? name_ja! : (name_en ?? id) }
    var logoURL: URL? {
        guard let p = image?.path, !p.isEmpty else { return nil }
        return URL(string: ProduceClient.baseURL + p)
    }
}

struct ProduceSeason: Codable, Hashable {
    let month: String
    let max_temp: Double
}

struct ProduceReason: Codable, Hashable {
    let kind: String     // taste | season | closet | budget
    let label: String    // テイスト / 季節 / 手持ち / 予算
    let text: String
}

struct ProduceItem: Codable, Hashable, Identifiable {
    let item_key: String
    let slot: String?
    let slot_label: String?
    let label: String
    let image_url: String?
    let reasons: [ProduceReason]
    let price_hint: String?
    let brand_id: String?
    var reaction: String? = nil

    var id: String { item_key }
}

struct ProduceOwnedResponse: Codable {
    let status: String
    let item_key: String
    let registered: Bool
    let item_id: String?
}

private struct ProduceOwnedBody: Encodable {
    let user_id: String
    let item_key: String
}

private struct ProduceFeedbackBody: Encodable {
    let user_id: String
    let item_key: String
    let reaction: String?
    let reason: String?
}

struct ProduceClient {
    static var baseURL: String {
        #if DEBUG
        // 動作確認用: ホームと同じキーで手元のサーバーへ向ける
        if let override = UserDefaults.standard.string(forKey: OwnedFirstHomeClient.debugBaseURLKey), !override.isEmpty {
            return override
        }
        #endif
        return OwnedFirstHomeClient.productionBaseURL
    }

    func fetch(userId: String, gender: String?, age: Int?, brandId: String? = nil) async -> Result<ProduceResponse, HTTPError> {
        var comps = URLComponents(string: "\(Self.baseURL)/api/produce")!
        var q = [URLQueryItem(name: "user_id", value: userId)]
        if let gender { q.append(URLQueryItem(name: "gender", value: gender)) }
        if let age { q.append(URLQueryItem(name: "age", value: String(age))) }
        if let brandId { q.append(URLQueryItem(name: "brand_id", value: brandId)) }
        comps.queryItems = q
        guard let url = comps.url else { return .failure(.responseError) }
        do {
            let (data, res) = try await URLSession.shared.data(from: url)
            guard (res as? HTTPURLResponse)?.statusCode == 200 else { return .failure(.responseError) }
            return .success(try JSONDecoder().decode(ProduceResponse.self, from: data))
        } catch {
            return .failure(.decodeError)
        }
    }

    /// reaction: like | dislike | owned | nil (取り消し)。reason は dislike のとき taste | season | price
    @discardableResult
    func sendFeedback(userId: String, itemKey: String, reaction: String?, reason: String? = nil) async -> Bool {
        guard let url = URL(string: "\(Self.baseURL)/api/produce/feedback") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(ProduceFeedbackBody(user_id: userId, item_key: itemKey,
                                                                     reaction: reaction, reason: reason))
        guard let (_, res) = try? await URLSession.shared.data(for: req) else { return false }
        return (res as? HTTPURLResponse)?.statusCode == 200
    }

    /// 「持ってる・買った」。登録できたら (もう持っていた場合も) レスポンスを返す
    func registerOwned(userId: String, itemKey: String) async -> ProduceOwnedResponse? {
        guard let url = URL(string: "\(Self.baseURL)/api/produce/owned") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 画像のコピーがあるので、Render のコールドスタートも見込んで長めに待つ
        req.timeoutInterval = 60
        req.httpBody = try? JSONEncoder().encode(ProduceOwnedBody(user_id: userId, item_key: itemKey))
        guard let (data, res) = try? await URLSession.shared.data(for: req),
              (res as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(ProduceOwnedResponse.self, from: data)
    }
}
