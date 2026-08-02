//
//  RecommendationPlanClient.swift
//  irodori
//
//  まとめ提案 (N日分コーデプラン) APIクライアント。
//  生成のみでサーバー保存はしない。承認後に CalendarOutfitClient.bulk で予定保存する。
//  2026-08: 週ナラティブ (週テーマ/週コメント/日別ノート)・候補の軸ラベル (alt_tag)・
//  候補数指定 (candidates_per_day) に対応。
//

import Foundation

/// 本命 / 入替候補の1件。アイテム本体 (DailyRecommendationItem) と、
/// まとめ提案のみが返す軸ラベル (steady=堅実 / challenge=挑戦 / change=気分転換) を持つ
struct OutfitPlanCandidate: Decodable, Identifiable {
    let item: DailyRecommendationItem
    let alt_tag: String?

    var id: String { item.id }

    private enum CodingKeys: String, CodingKey {
        case alt_tag
    }

    init(from decoder: Decoder) throws {
        self.item = try DailyRecommendationItem(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.alt_tag = try? c.decode(String.self, forKey: .alt_tag)
    }

    init(item: DailyRecommendationItem, alt_tag: String? = nil) {
        self.item = item
        self.alt_tag = alt_tag
    }
}

struct OutfitPlanDay: Decodable, Identifiable {
    let date: String                                // YYYY-MM-DD
    let weather: DailyRecommendationWeather?
    let item: OutfitPlanCandidate                   // 本命
    let alternates: [OutfitPlanCandidate]           // 入替候補 (既定3 / 要求時 最大14)
    let day_line: String?                           // その日のひとこと (週ナラティブ or 理由文)
    var id: String { date }
}

struct OutfitPlanResponse: Decodable {
    let status: String
    let days: [OutfitPlanDay]
    // 相棒の語り (旧サーバ応答には無いため全て Optional)
    let week_title: String?                         // 週テーマ (12〜20字)
    let week_comment: String?                       // 週の宣言 (60〜90字)
    let plan_ack: String?                           // 「先週の声、今週こう変えた」(効いた時だけ)
    let signal_count: Int?                          // 根拠バッジ: 選定に使った記録数
    let signal_caption: String?
    let speaking_style: String?                     // 相棒の話し方キー (normal/spicy 等)
}

protocol RecommendationPlanClientProtocol {
    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String?,
        prefectureCode: String?,
        candidatesPerDay: Int?
    ) async throws -> Result<OutfitPlanResponse, HTTPError>
}

final class RecommendationPlanClient: RecommendationPlanClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct RequestBody: Encodable {
        let gender: String
        let days: Int
        let start_date: String?
        let prefecture_code: String?
        let candidates_per_day: Int?
    }

    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String?,
        prefectureCode: String?,
        candidatesPerDay: Int?
    ) async throws -> Result<OutfitPlanResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/recommendation/plan")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // 31日分は日数ぶん生成が走るため長め
        request.httpBody = try? JSONEncoder().encode(
            RequestBody(
                gender: gender.apiValue,
                days: days,
                start_date: startDate,
                prefecture_code: prefectureCode,
                candidates_per_day: candidatesPerDay
            )
        )

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(OutfitPlanResponse.self, from: data))
            } catch {
                print("[RecommendationPlanClient] decode error: \(error)")
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

// MARK: - Mock

final class MockRecommendationPlanClient: RecommendationPlanClientProtocol {
    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String?,
        prefectureCode: String?,
        candidatesPerDay: Int?
    ) async throws -> Result<OutfitPlanResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let start = startDate.flatMap { formatter.date(from: $0) } ?? Date()
        let genres = ["casual", "korean", "office_casual", "sporty"]
        let perDay = max(2, min(candidatesPerDay ?? 4, 15))

        func makeItem(day: Int, seed: Int, discovery: Bool = false, owned: Int = 0) -> DailyRecommendationItem {
            DailyRecommendationItem(
                pool_id: "m_\(day)_\(seed)", kind: "pool",
                image_url: "https://example.com/\(day)_\(seed).jpg",
                reason: seed == 0 ? "手持ちのネイビーパンツがそのまま活きる。" : nil,
                main_colors: [], items: [:],
                vibe: "", style: genres[(day + seed) % genres.count], cleanliness: 3,
                is_favorite: false, is_discovery: discovery,
                owned_items: (0..<owned).map { i in
                    DailyOwnedItem(
                        slot: i == 0 ? "tops" : "bottoms",
                        item_id: "c_\(day)_\(i)",
                        image_url: "https://example.com/item\(i).jpg",
                        label: i == 0 ? "白 シャツ" : "ネイビー パンツ"
                    )
                }
            )
        }

        let planDays = (0..<days).map { offset -> OutfitPlanDay in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            return OutfitPlanDay(
                date: formatter.string(from: date),
                weather: .init(min_temp: 21, max_temp: 29, condition: "晴れ時々くもり", area_code: "130000"),
                item: OutfitPlanCandidate(item: makeItem(day: offset, seed: 0, owned: offset % 3)),
                alternates: (1..<perDay).map { seed in
                    OutfitPlanCandidate(
                        item: makeItem(day: offset, seed: seed, discovery: seed == 2, owned: seed % 3),
                        alt_tag: ["steady", "challenge", "change"][safe: seed - 1]
                    )
                },
                day_line: "この日は晴れ予報。薄手のレイヤードで気楽に。"
            )
        }
        return .success(.init(
            status: "success",
            days: planDays,
            week_title: "手持ちで勝つ一週間",
            week_comment: "今週は手持ちが活きる日が多い。木曜だけ、いつもと違う系統を混ぜておいた。",
            plan_ack: nil,
            signal_count: 42,
            signal_caption: "あなたの42回の記録と週間予報から組んだ提案だよ",
            speaking_style: "normal"
        ))
    }
}
