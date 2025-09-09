import Foundation

struct AnalysisCoordinateRequest: Encodable {
    let image_id: Int
    let gender: String
    
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["image_id"] = image_id
        parameters["gender"] = gender
        return parameters
    }
}

extension AnalysisCoordinateRequest {
    static let mock = AnalysisCoordinateRequest(
        image_id: 1,
        gender: "men"
    )
}
