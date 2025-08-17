//
//  HTTPError.swift
//

import Foundation

enum HTTPError: Error {
    /// レスポンスを受け取れなかった
    case responseError

    /// レスポンスを正しくデコードできなかった
    case decodeError

    // 4xx クライアントエラー
    case badRequest  // 400 Bad Request
    case unauthorized  // 401 Unauthorized
    case forbidden  // 403 Forbidden
    case notFound  // 404 Not Found
    case methodNotAllowed  // 405 Method Not Allowed
    case requestTimeout  // 408 Request Timeout
    case conflict  // 409 Conflict
    case tooManyRequests  // 429 Too Many Requests
    case clientError(Int)  // その他の4xxエラー

    // 5xx サーバーエラー
    case internalServerError  // 500 Internal Server Error
    case notImplemented  // 501 Not Implemented
    case badGateway  // 502 Bad Gateway
    case serviceUnavailable  // 503 Service Unavailable
    case gatewayTimeout  // 504 Gateway Timeout
    case serverError(Int)  // その他の5xxエラー

    case unknownError  // 未知のエラー

    var title: String {
        switch self {
        // 通信・接続関連のエラー
        case .responseError, .requestTimeout, .gatewayTimeout, .serviceUnavailable:
            return "通信エラー"
        // サーバー側の問題に起因するエラー
        case .internalServerError, .notImplemented, .badGateway, .serverError:
            return "サーバーエラー"
        // クライアント側のリクエストに起因するエラー
        case .badRequest, .unauthorized, .forbidden, .notFound, .methodNotAllowed, .conflict, .tooManyRequests, .clientError:
            return "リクエストエラー"
        // データの処理に関するエラー
        case .decodeError:
            return "データエラー"
        // 上記のいずれにも分類されないエラー
        case .unknownError:
            return "不明なエラー"
        }
    }

    var errorDescription: String {
        switch self {
        case .responseError:
            return "通信状況に問題があるかもしれません"
        case .decodeError:
            return "データのデコード中にエラーが発生しました"
        // 4xx クライアントエラー
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
        // 5xx サーバーエラー
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
    
    static func fromStatusCode(_ statusCode: Int) -> HTTPError {
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
        case 400..<500:
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
        case 500..<600:
            return .serverError(statusCode)
        default:
            return .unknownError
        }
    }
}
