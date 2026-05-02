//
//  CoordinateListClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/07/17.
//

import Foundation

protocol CoordinateListClientProtocol {
    func get(uid: String, year: Int, month: Int) async throws -> Result<[CoordinateListResponse], Error>
}

final class CoordinateListClient: CoordinateListClientProtocol {
    func get(uid: String, year: Int, month: Int) async throws -> Result<[CoordinateListResponse], Error> {
//        let baseURL = "https://nfzoiluhpi.execute-api.ap-northeast-1.amazonaws.com/prod/"
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/coordinate/list/\(uid)"
        let url = URL(string: "\(baseURL)/\(endpoint)?year=\(year)&month=\(month)")!

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            // URLSessionでリクエストを送信
            let (data, _) = try await URLSession.shared.data(for: request)
            print(data)
            // JSONレスポンスをデコード
            let response = try JSONDecoder().decode([CoordinateListResponse].self, from: data)
            return .success(response)
        } catch {
            // TODO: エラーハンドリング
            print(error.localizedDescription)
            return .failure(error)
        }
    }
}

// MARK: - Mock

final class MockCoordinateListClient: CoordinateListClientProtocol {
    // coordinate-1〜10 をランダムな日付に割り当て
    private let imageNames = (1...10).map { "coordinate-\($0)" }

    func get(uid: String, year: Int, month: Int) async throws -> Result<[CoordinateListResponse], Error> {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return .success([]) }

        // 画像を割り当てる日を固定（再現性のため決定論的に選ぶ）
        let totalDays = range.count
        let imageDays: Set<Int> = [1, 3, 5, 8, 10, 14, 17, 20, 24, 28]
            .filter { $0 <= totalDays }
            .reduce(into: Set<Int>()) { $0.insert($1) }

        let responses = (1...totalDays).map { day -> CoordinateListResponse in
            let imageIndex = imageDays.sorted().firstIndex(of: day)
            let imageName = imageIndex.map { imageNames[$0 % imageNames.count] }
            return CoordinateListResponse(year: year, month: month, day: day, id: nil, coodinate_image_path: imageName)
        }
        return .success(responses)
    }
}
