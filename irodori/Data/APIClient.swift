//
//  APIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation
import Combine

// MARK: - APIClient Protocol

protocol APIClientProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) -> AnyPublisher<T, APIError>
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data, responseType: T.Type) -> AnyPublisher<T, APIError>
}

// MARK: - APIClient Implementation

class APIClient: APIClientProtocol {
    static let shared = APIClient()
    
    private let baseURL: String = "http://localhost:8080"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: baseURL + endpoint.path) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = endpoint.body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return Fail(error: APIError.encodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw APIError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: responseType, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError
                }
            }
            .eraseToAnyPublisher()
    }
    
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data, responseType: T.Type) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: baseURL + endpoint.path) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add form fields
        if let formData = endpoint.body as? [String: Any] {
            for (key, value) in formData {
                if key == "file" {
                    // Handle file upload
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
                    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                    body.append(data)
                    body.append("\r\n".data(using: .utf8)!)
                } else {
                    // Handle regular form fields
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                    body.append("\(value)\r\n".data(using: .utf8)!)
                }
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw APIError.httpError(httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: responseType, decoder: JSONDecoder())
            .mapError { error in
                if let apiError = error as? APIError {
                    return apiError
                } else if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError
                }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - APIEndpoint

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let body: [String: Any]?
    
    init(path: String, method: HTTPMethod, body: [String: Any]? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - APIError

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case encodingError
    case decodingError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        case .encodingError:
            return "Encoding error"
        case .decodingError:
            return "Decoding error"
        case .networkError:
            return "Network error"
        }
    }
}