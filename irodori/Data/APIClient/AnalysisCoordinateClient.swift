import Foundation
import UIKit

protocol AnalysisCoordinateClientProtocol {
    func analysisCoordinate(id: Int, gender: String) async throws -> AnalysisCoordinateResponse
}

struct AnalysisCoordinateClient: AnalysisCoordinateClientProtocol {
    func analysisCoordinate(id: Int, gender: String) async throws -> AnalysisCoordinateResponse {
        guard let url = URL(string: "https://irodori-api.onrender.com/analysis-coordinate") else {
            throw URLError(.badURL)
        }
        
        let requestBody = AnalysisCoordinateRequest(
            image_id: id,
            gender: gender
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let requestData = try JSONEncoder().encode(requestBody)
            request.httpBody = requestData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw HTTPError.fromStatusCode(httpResponse.statusCode)
                }
            }
            
            let coordinateResponse = try JSONDecoder().decode(AnalysisCoordinateResponse.self, from: data)
            return coordinateResponse
        } catch {
            throw error
        }
    }
}

struct MockAnalysisCoordinateClient: AnalysisCoordinateClientProtocol {
    func analysisCoordinate(id: Int, gender: String) async throws -> AnalysisCoordinateResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return AnalysisCoordinateResponse.mock
    }
}

// テスト用の空データを返すMockクライアント
struct MockEmptyAnalysisCoordinateClient: AnalysisCoordinateClientProtocol {
    func analysisCoordinate(id: Int, gender: String) async throws -> AnalysisCoordinateResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        return AnalysisCoordinateResponse.mockEmpty
    }
}

// テスト用のエラーを返すMockクライアント
struct MockErrorAnalysisCoordinateClient: AnalysisCoordinateClientProtocol {
    func analysisCoordinate(id: Int, gender: String) async throws -> AnalysisCoordinateResponse {
        try await Task.sleep(nanoseconds: 500_000_000)
        throw URLError(.timedOut)
    }
}
