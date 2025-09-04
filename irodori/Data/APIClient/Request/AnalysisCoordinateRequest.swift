import Foundation

struct AnalysisCoordinateRequest: Encodable {
    let image_base64: String
    let gender: String
    
    func createParameters() -> [String: Any] {
        var parameters: [String: Any] = [:]
        parameters["image_base64"] = image_base64
        parameters["gender"] = gender
        return parameters
    }
}

extension AnalysisCoordinateRequest {
    static let mock = AnalysisCoordinateRequest(
        image_base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+P//PwAFhAJ/wlseKgAAAABJRU5ErkJggg==",
        gender: "men"
    )
}