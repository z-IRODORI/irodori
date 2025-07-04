//
//  HTTPError.swift
//  irodori
//
//  Created by Claude on 2025/07/04.
//

import Foundation

enum HTTPError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case methodNotAllowed
    case requestTimeout
    case conflict
    case preconditionFailed
    case unprocessableEntity
    case tooManyRequests
    case internalServerError
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    case networkError
    case decodingError
    case encodingError
    case unknown(Int)
    
    init(statusCode: Int) {
        switch statusCode {
        case 401:
            self = .unauthorized
        case 403:
            self = .forbidden
        case 404:
            self = .notFound
        case 405:
            self = .methodNotAllowed
        case 408:
            self = .requestTimeout
        case 409:
            self = .conflict
        case 412:
            self = .preconditionFailed
        case 422:
            self = .unprocessableEntity
        case 429:
            self = .tooManyRequests
        case 500:
            self = .internalServerError
        case 502:
            self = .badGateway
        case 503:
            self = .serviceUnavailable
        case 504:
            self = .gatewayTimeout
        default:
            self = .unknown(statusCode)
        }
    }
    
    var title: String {
        switch self {
        case .invalidURL:
            return "無効なURL"
        case .invalidResponse:
            return "無効なレスポンス"
        case .unauthorized:
            return "認証エラー"
        case .forbidden:
            return "アクセス拒否"
        case .notFound:
            return "見つかりません"
        case .methodNotAllowed:
            return "許可されていないメソッド"
        case .requestTimeout:
            return "リクエストタイムアウト"
        case .conflict:
            return "競合エラー"
        case .preconditionFailed:
            return "前提条件エラー"
        case .unprocessableEntity:
            return "処理できないデータ"
        case .tooManyRequests:
            return "リクエスト過多"
        case .internalServerError:
            return "サーバーエラー"
        case .badGateway:
            return "ゲートウェイエラー"
        case .serviceUnavailable:
            return "サービス利用不可"
        case .gatewayTimeout:
            return "ゲートウェイタイムアウト"
        case .networkError:
            return "ネットワークエラー"
        case .decodingError:
            return "データ解析エラー"
        case .encodingError:
            return "データエンコードエラー"
        case .unknown(let statusCode):
            return "不明なエラー (\(statusCode))"
        }
    }
    
    var message: String {
        switch self {
        case .invalidURL:
            return "リクエストURLが正しくありません。"
        case .invalidResponse:
            return "サーバーからの応答が正しくありません。"
        case .unauthorized:
            return "認証情報が無効です。再ログインしてください。"
        case .forbidden:
            return "このリソースへのアクセス権限がありません。"
        case .notFound:
            return "要求されたリソースが見つかりません。"
        case .methodNotAllowed:
            return "このメソッドは許可されていません。"
        case .requestTimeout:
            return "リクエストがタイムアウトしました。"
        case .conflict:
            return "データの競合が発生しました。"
        case .preconditionFailed:
            return "前提条件が満たされていません。"
        case .unprocessableEntity:
            return "送信されたデータが処理できません。"
        case .tooManyRequests:
            return "リクエスト回数が上限を超えました。しばらく待ってから再試行してください。"
        case .internalServerError:
            return "サーバーで内部エラーが発生しました。"
        case .badGateway:
            return "ゲートウェイエラーが発生しました。"
        case .serviceUnavailable:
            return "サービスが一時的に利用できません。"
        case .gatewayTimeout:
            return "ゲートウェイがタイムアウトしました。"
        case .networkError:
            return "ネットワーク接続を確認してください。"
        case .decodingError:
            return "受信したデータの形式が正しくありません。"
        case .encodingError:
            return "データの送信準備中にエラーが発生しました。"
        case .unknown(let statusCode):
            return "予期しないエラーが発生しました。(ステータスコード: \(statusCode))"
        }
    }
}

extension HTTPError: LocalizedError {
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return title
    }
}