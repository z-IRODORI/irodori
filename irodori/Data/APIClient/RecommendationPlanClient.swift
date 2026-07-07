//
//  RecommendationPlanClient.swift
//  irodori
//
//  まとめ提案 (N日分コーデプラン) APIクライアント。
//  生成のみでサーバー保存はしない。承認後に CalendarOutfitClient.bulk で予定保存する。
//

import Foundation

struct OutfitPlanDay: Decodable, Identifiable {
    let date: String                                // YYYY-MM-DD
    let weather: DailyRecommendationWeather?
    let item: DailyRecommendationItem               // 本命
    let alternates: [DailyRecommendationItem]       // 入替候補 (最大3)
    var id: String { date }
}

struct OutfitPlanResponse: Decodable {
    let status: String
    let days: [OutfitPlanDay]
}

protocol RecommendationPlanClientProtocol {
    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String?,
        prefectureCode: String?
    ) async throws -> Result<OutfitPlanResponse, HTTPError>
}

final class RecommendationPlanClient: RecommendationPlanClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    private struct RequestBody: Encodable {
        let gender: String
        let days: Int
        let start_date: String?
        let prefecture_code: String?
    }

    func plan(
        uid: String,
        gender: Gender,
        days: Int,
        startDate: String?,
        prefectureCode: String?
    ) async throws -> Result<OutfitPlanResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/recommendation/plan")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.responseError) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120  // 31日分は日数ぶん生成が走るため長め
        request.httpBody = try? JSONEncoder().encode(
            RequestBody(gender: gender.apiValue, days: days, start_date: startDate, prefecture_code: prefectureCode)
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
        prefectureCode: String?
    ) async throws -> Result<OutfitPlanResponse, HTTPError> {
        try? await Task.sleep(nanoseconds: 500_000_000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let start = startDate.flatMap { formatter.date(from: $0) } ?? Date()
        let planDays = (0..<days).map { offset -> OutfitPlanDay in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            return OutfitPlanDay(
                date: formatter.string(from: date),
                weather: nil,
                item: DailyRecommendationItem(
                    pool_id: "m_\(offset)", kind: "pool",
                    image_url: "https://example.com/\(offset).jpg",
                    reason: nil, main_colors: [], items: [:],
                    vibe: "", style: "casual", cleanliness: 3, is_favorite: false
                ),
                alternates: []
            )
        }
        return .success(.init(status: "success", days: planDays))
    }
}
