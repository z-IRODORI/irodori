//
//  APIRequestProtocol.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

protocol APIRequestProtocol: Sendable {
    associatedtype Response: Decodable
    
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}

extension APIRequestProtocol {
    var baseURL: URL {
        URL(string: "https://irodori.click")!
    }
    
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var headers: [String: String] { [:] }
    
    func buildURL(baseURL: String) -> URL? {
        guard let baseURL = URL(string: baseURL) else { return nil }
        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        return components?.url
    }
    
    func buildURLRequest() -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        
        switch method {
        case .get:
            if let queryItems = queryItems, !queryItems.isEmpty {
                components?.queryItems = queryItems
            }
            urlRequest.url = components?.url
            return urlRequest
        case .post, .put, .patch:
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = body
            return urlRequest
        case .delete:
            headers.forEach { key, value in
                urlRequest.addValue(value, forHTTPHeaderField: key)
            }
            return urlRequest
        default:
            return urlRequest
        }
    }
}

// MARK: - JSON Request Protocol

protocol JSONRequestProtocol: APIRequestProtocol {
    associatedtype RequestBody: Encodable
    var requestBody: RequestBody? { get }
}

extension JSONRequestProtocol {
    var body: Data? {
        guard let requestBody = requestBody else { return nil }
        return try? JSONEncoder().encode(requestBody)
    }
    
    var headers: [String: String] {
        ["Content-Type": "application/json"]
    }
}

// MARK: - Multipart Request Protocol

protocol MultipartRequestProtocol: APIRequestProtocol {
    var formData: [String: Any] { get }
    var fileData: Data? { get }
    var fileName: String? { get }
    var fieldName: String { get }
}

extension MultipartRequestProtocol {
    var fieldName: String { "file" }
    var fileName: String? { "image.jpg" }
    
    var body: Data? {
        let boundary = UUID().uuidString
        var data = Data()
        
        let boundaryText = "--\(boundary)\r\n"
        
        for (key, value) in formData {
            switch value {
            case let imageData as Data:
                data.append(boundaryText.data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(fileName ?? "image.jpg")\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                data.append(imageData)
                data.append("\r\n".data(using: .utf8)!)
            case let string as String:
                data.append(boundaryText.data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                data.append(string.data(using: .utf8)!)
                data.append("\r\n".data(using: .utf8)!)
            default:
                data.append(boundaryText.data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                data.append(String(describing: value).data(using: .utf8)!)
                data.append("\r\n".data(using: .utf8)!)
            }
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
    
    var headers: [String: String] {
        let boundary = UUID().uuidString
        return ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
    }
}