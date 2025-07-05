//
//  APIClient.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

// MARK: - API Configuration

struct APIConfiguration {
    let baseURL: String
    let timeout: TimeInterval
    let decoder: JSONDecoder
    
    static let `default` = APIConfiguration(
        baseURL: "https://irodori.click",
        timeout: 30.0,
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    )
    
    static let local = APIConfiguration(
        baseURL: "http://localhost:8080",
        timeout: 30.0,
        decoder: {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return decoder
        }()
    )
}

// MARK: - HTTP Error

enum HTTPError: Error {
    case responseError
    case decodeError
    
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case methodNotAllowed
    case requestTimeout
    case conflict
    case tooManyRequests
    case clientError(Int)
    
    case internalServerError
    case notImplemented
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    case serverError(Int)
    
    case unknownError
    
    var title: String {
        switch self {
        case .responseError, .requestTimeout, .gatewayTimeout, .serviceUnavailable:
            return "通信エラー"
        case .internalServerError, .notImplemented, .badGateway, .serverError:
            return "サーバーエラー"
        case .badRequest, .unauthorized, .forbidden, .notFound, .methodNotAllowed, .conflict, .tooManyRequests, .clientError:
            return "リクエストエラー"
        case .decodeError:
            return "データエラー"
        case .unknownError:
            return "不明なエラー"
        }
    }
    
    var errorDescription: String {
        switch self {
        case .responseError:
            return "レスポンスを受信できませんでした"
        case .decodeError:
            return "データのデコード中にエラーが発生しました"
        case .badRequest:
            return "リクエストが無効です (400)"
        case .unauthorized:
            return "認証に失敗しました (401)"
        case .forbidden:
            return "アクセスが拒否されました (403)"
        case .notFound:
            return "リソースが見つかりません (404)"
        case .methodNotAllowed:
            return "許可されていないメソッドです (405)"
        case .requestTimeout:
            return "リクエストがタイムアウトしました (408)"
        case .conflict:
            return "リクエストが競合しています (409)"
        case .tooManyRequests:
            return "リクエスト回数の上限を超えました (429)"
        case .clientError(let code):
            return "クライアントエラーが発生しました (\(code))"
        case .internalServerError:
            return "サーバー内部でエラーが発生しました (500)"
        case .notImplemented:
            return "機能が実装されていません (501)"
        case .badGateway:
            return "不正なゲートウェイです (502)"
        case .serviceUnavailable:
            return "サービスが利用できません (503)"
        case .gatewayTimeout:
            return "ゲートウェイがタイムアウトしました (504)"
        case .serverError(let code):
            return "サーバーエラーが発生しました (\(code))"
        case .unknownError:
            return "未知のエラーが発生しました"
        }
    }
}

// MARK: - API Client Protocol

protocol APIClientProtocol: Sendable {
    func request<R: APIRequestProtocol>(
        _ apiRequest: R
    ) async throws -> Result<R.Response, HTTPError>
}

// MARK: - API Client

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
            return .failure(.badRequest)
        }
        
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = apiRequest.method.rawValue
        request.httpBody = apiRequest.body
        
        for (key, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.responseError)
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                if httpResponse.statusCode == 204 && R.Response.self == EmptyResponse.self {
                    return .success(EmptyResponse() as! R.Response)
                }
                do {
                    let decodedResponse = try configuration.decoder.decode(R.Response.self, from: data)
                    return .success(decodedResponse)
                } catch {
                    return .failure(.decodeError)
                }
            case 400..<600:
                let error = errorHandling(statusCode: httpResponse.statusCode)
                return .failure(error)
            default:
                return .failure(.unknownError)
            }
            
        } catch {
            return .failure(.requestTimeout)
        }
    }
}

// MARK: - Error Handling Extension

extension APIClient {
    func errorHandling(statusCode: Int) -> HTTPError {
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 405:
            return .methodNotAllowed
        case 408:
            return .requestTimeout
        case 409:
            return .conflict
        case 429:
            return .tooManyRequests
        case 400...499:
            return .clientError(statusCode)
        case 500:
            return .internalServerError
        case 501:
            return .notImplemented
        case 502:
            return .badGateway
        case 503:
            return .serviceUnavailable
        case 504:
            return .gatewayTimeout
        case 500...599:
            return .serverError(statusCode)
        default:
            return .unknownError
        }
    }
}

// MARK: - Empty Response

struct EmptyResponse: Codable {
    init() {}
}