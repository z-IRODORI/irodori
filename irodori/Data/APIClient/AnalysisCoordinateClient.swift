import Foundation
import UIKit

protocol AnalysisCoordinateClientProtocol {
    func analysisCoordinate(image: UIImage, gender: String) async throws -> AnalysisCoordinateResponse
}

struct AnalysisCoordinateClient: AnalysisCoordinateClientProtocol {
    func analysisCoordinate(image: UIImage, gender: String) async throws -> AnalysisCoordinateResponse {
        guard let url = URL(string: "https://irodori-api.onrender.com/analysis-coordinate") else {
            throw URLError(.badURL)
        }
        
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        let base64String = jpegData.base64EncodedString()
        
        let requestBody = AnalysisCoordinateRequest(
            image_base64: base64String,
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
    func analysisCoordinate(image: UIImage, gender: String) async throws -> AnalysisCoordinateResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return AnalysisCoordinateResponse.mock
    }
}
