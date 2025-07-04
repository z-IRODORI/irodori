//
//  APIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

protocol APIClientProtocol: Sendable {
    func request<R: APIRequestProtocol>(
        _ apiRequest: R
    ) async throws -> Result<R.Response, HTTPError>
}

final class APIClient: APIClientProtocol {
    static let shared = APIClient()
    
    private let configuration: APIConfiguration
    private let session: URLSession
    
    init(configuration: APIConfiguration = .default, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }
    
    func request<R: APIRequestProtocol>(
        _ apiRequest: R
    ) async throws -> Result<R.Response, HTTPError> {
        
        guard let url = apiRequest.buildURL(baseURL: configuration.baseURL) else {
            return .failure(.invalidURL)
        }
        
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = apiRequest.method.rawValue
        request.httpBody = apiRequest.body
        
        // Set headers
        for (key, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // Handle HTTP status codes
            guard 200...299 ~= httpResponse.statusCode else {
                return .failure(HTTPError(statusCode: httpResponse.statusCode))
            }
            
            // Handle empty response for 204 No Content
            if httpResponse.statusCode == 204 {
                // For empty responses, try to create an empty instance if possible
                if let emptyResponse = EmptyResponse() as? R.Response {
                    return .success(emptyResponse)
                }
            }
            
            // Decode response
            do {
                let decodedResponse = try configuration.decoder.decode(R.Response.self, from: data)
                return .success(decodedResponse)
            } catch {
                return .failure(.decodingError)
            }
            
        } catch {
            return .failure(.networkError)
        }
    }
}

// MARK: - Empty Response for 204 status codes

struct EmptyResponse: Codable {
    init() {}
}