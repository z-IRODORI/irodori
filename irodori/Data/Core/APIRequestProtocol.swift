//
//  APIRequestProtocol.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

protocol APIRequestProtocol: Sendable {
    associatedtype Response: Decodable
    
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    var requiresAuthentication: Bool { get }
}

extension APIRequestProtocol {
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var headers: [String: String] { [:] }
    var requiresAuthentication: Bool { false }
    
    func buildURL(baseURL: String) -> URL? {
        guard var components = URLComponents(string: baseURL + path) else {
            return nil
        }
        
        if let queryItems = queryItems {
            components.queryItems = queryItems
        }
        
        return components.url
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
        
        // Add form fields
        for (key, value) in formData {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data if present
        if let fileData = fileData, let fileName = fileName {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            data.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return data
    }
    
    var headers: [String: String] {
        let boundary = UUID().uuidString
        return ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
    }
}