//
//  BrandMatchClient.swift
//  irodori
//
//  あなたに合うブランド 10 選 (irodori-api の /api/brand-match)。
//  GET  /api/brand-match?user_id=&gender=&age=   → 10 選 (ブランドの事実は調査マスタの値)
//  POST /api/brand-match/feedback                 → 好き / 持ってる / 知ってた / 興味なし
//  POST /api/brand-match/price-feedback           → 価格帯が 高い / ちょうどいい / 安い (予算感を直し、相棒のミッションに数える)
//

import Foundation

protocol BrandMatchClientProtocol {
    func fetch(userId: String, gender: String, age: Int?) async -> Result<BrandMatchResponse, HTTPError>
    func sendFeedback(userId: String, brandId: String, reaction: BMReaction?) async
    func sendPriceFeedback(userId: String, brandId: String, verdict: BMPriceVerdict?) async -> BrandPriceFeedbackResponse?
}

final class BrandMatchClient: BrandMatchClientProtocol {
    static let baseURL = "https://irodori-api.onrender.com"

    func fetch(userId: String, gender: String, age: Int?) async -> Result<BrandMatchResponse, HTTPError> {
        var comps = URLComponents(string: "\(Self.baseURL)/api/brand-match")!
        var items = [URLQueryItem(name: "user_id", value: userId), URLQueryItem(name: "gender", value: gender)]
        if let age { items.append(URLQueryItem(name: "age", value: String(age))) }
        comps.queryItems = items
        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 60   // Render のスリープ明けを待つ
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(http.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(BrandMatchResponse.self, from: data))
            } catch {
                print("[BrandMatch] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print("[BrandMatch] request error: \(error.localizedDescription)")
            return .failure(.responseError)
        }
    }

    func sendFeedback(userId: String, brandId: String, reaction: BMReaction?) async {
        guard let url = URL(string: "\(Self.baseURL)/api/brand-match/feedback") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = BrandMatchFeedbackRequest(user_id: userId, brand_id: brandId, reaction: reaction?.apiValue)
        request.httpBody = try? JSONEncoder().encode(body)
        _ = try? await URLSession.shared.data(for: request)
    }

    func sendPriceFeedback(userId: String, brandId: String, verdict: BMPriceVerdict?) async -> BrandPriceFeedbackResponse? {
        guard let url = URL(string: "\(Self.baseURL)/api/brand-match/price-feedback") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let body = BrandPriceFeedbackRequest(user_id: userId, brand_id: brandId, verdict: verdict?.rawValue)
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 { return nil }
            return try JSONDecoder().decode(BrandPriceFeedbackResponse.self, from: data)
        } catch {
            print("[BrandMatch] price feedback error: \(error.localizedDescription)")
            return nil
        }
    }
}

private struct BrandPriceFeedbackRequest: Encodable {
    let user_id: String
    let brand_id: String
    let verdict: String?

    // verdict が nil のときも null を送る (返事を取り消す)
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(brand_id, forKey: .brand_id)
        try c.encode(verdict, forKey: .verdict)
    }

    enum CodingKeys: String, CodingKey { case user_id, brand_id, verdict }
}

/// 価格帯への返事の結果: 直した予算感と、相棒の成長 (ミッションで増えた理解度)
struct BrandPriceFeedbackResponse: Decodable {
    let status: String
    let verdict: String?
    let budget: BrandMatchResponse.Budget?
    let growth: Growth

    struct Growth: Decodable {
        let gained_pct: Int
        let answers: Int
        let next_target: Int?
    }
}

private struct BrandMatchFeedbackRequest: Encodable {
    let user_id: String
    let brand_id: String
    let reaction: String?

    // reaction が nil のときも null を送る (反応を取り消す)
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user_id, forKey: .user_id)
        try c.encode(brand_id, forKey: .brand_id)
        try c.encode(reaction, forKey: .reaction)
    }

    enum CodingKeys: String, CodingKey { case user_id, brand_id, reaction }
}

// MARK: - レスポンス

struct BrandMatchResponse: Decodable {
    let status: String
    let type_code: String?
    let type_name: String?
    let scores: Scores?
    let closet: [String]?
    let partner_line: String?
    /// 予算感 (価格帯への返事で直した値。古いサーバでは nil)
    let budget: Budget?
    let picks: [Pick]

    struct Budget: Decodable {
        let tier: Double
        let base: Double
        let answers: Int
    }

    struct Scores: Decodable {
        let trend: Double
        let selfScore: Double
        let social: Double
        let function: Double
        let economy: Double

        enum CodingKeys: String, CodingKey {
            case trend, social, function, economy
            case selfScore = "self"
        }
    }

    struct Pick: Decodable {
        let slot: String
        let score: Double
        let reasons: [String]
        let points: [String]
        let reaction: String?
        /// 価格帯への返事 (high / just / low)
        let price_feedback: String?
        let brand: Brand
    }

    struct Brand: Decodable {
        let id: String
        let name_en: String
        let name_ja: String
        let segment_ja: String
        let founded_year: Int?
        let founder: String?
        let company: String?
        let history: String?
        let features: String?
        let summary: String?
        let position: String?
        let price: Price
        let target: Target
        let channels_ja: [String]
        let style_tags_ja: [String]
        let sub_tags_ja: [String]
        let axes: Scores
        let official_url: String?
        let image: Image?

        struct Price: Decodable {
            let tier: Int
            let range_text: String?
        }

        struct Target: Decodable {
            let persona: String?
        }

        struct Image: Decodable {
            let path: String
            let kind: String
            let label: String
            let dark: Bool
            let source: String?
            let source_page: String?
            let license: String?
        }
    }
}

// MARK: - 画面のモデルへ

extension BMReaction {
    var apiValue: String {
        switch self {
        case .like: return "like"
        case .owned: return "owned"
        case .known: return "known"
        case .notInterested: return "not_interested"
        }
    }

    init?(apiValue: String?) {
        switch apiValue {
        case "like": self = .like
        case "owned": self = .owned
        case "known": self = .known
        case "not_interested": self = .notInterested
        default: return nil
        }
    }
}

extension BrandMatchResponse {
    /// 画面で使う形に。userId は反応の保存先を分けるための ID
    func persona(userId: String) -> BMPersona? {
        guard status == "success", let s = scores, let typeName = type_name else { return nil }
        let picks: [BMPick] = picks.compactMap { p in
            guard let slot = BMSlot(apiValue: p.slot) else { return nil }
            return BMPick(brand: p.brand.model, slot: slot, reasons: p.reasons, points: p.points, score: p.score)
        }
        return BMPersona(
            id: userId, typeName: typeName, sub: "", typeCode: type_code ?? "",
            scores: [s.trend, s.selfScore, s.social, s.function], economy: s.economy,
            closet: closet ?? [], partnerLine: partner_line ?? "", picks: picks)
    }
}

extension BrandMatchResponse.Brand {
    var model: BMBrand {
        BMBrand(
            id: id, nameEn: name_en, nameJa: name_ja, segment: segment_ja, tier: price.tier,
            priceRange: price.range_text, foundedYear: founded_year, founder: founder, company: company,
            channels: channels_ja, styleTags: style_tags_ja, subTags: sub_tags_ja,
            features: features, summary: summary, history: history, position: position,
            targetPersona: target.persona,
            axes: [axes.trend, axes.selfScore, axes.social, axes.function],
            officialURL: official_url,
            image: image.map { im in
                BMImage(file: "", kind: BMImageKind(apiValue: im.kind), label: im.label, dark: im.dark,
                        source: im.source, sourcePage: im.source_page, license: im.license,
                        url: URL(string: BrandMatchClient.baseURL + im.path))
            })
    }
}

extension BMImageKind {
    init(apiValue: String) {
        switch apiValue {
        case "company_logo": self = .companyLogo
        case "designer_photo": self = .designerPhoto
        case "brand_photo": self = .brandPhoto
        case "company_photo": self = .companyPhoto
        case "brand_visual": self = .brandVisual
        case "brand_icon": self = .brandIcon
        default: self = .brandLogo
        }
    }
}
