//
//  FashionReviewClient.swift
//  irodori
//
//  Created by yuki.hamada on 2025/05/30.
//

import UIKit

protocol FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, topsImage: UIImage?, bottomsImage: UIImage?, cutoutImage: UIImage?, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError>
    /// 保存済みコーデから撮影直後と同じ形の解析結果を取得する
    /// (バックグラウンドジョブ完了後の結果画面用)
    func fetchResult(coordinateId: String, uid: String) async throws -> Result<FashionReviewResponse, HTTPError>
}

final class FashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, topsImage: UIImage?, bottomsImage: UIImage?, cutoutImage: UIImage?, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        let endpoint = "api/fashion_review"
        let url = URL(string: "\(baseURL)/\(endpoint)")!

        // UIImageをJPEGデータに変換
        guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
            return .failure(.badRequest)
        }

        // tops_imageとbottoms_imageをData形式に変換
        let topsData = topsImage?.jpegData(compressionQuality: 0.5)
        let bottomsData = bottomsImage?.jpegData(compressionQuality: 0.5)
        // 人物切り取りは背景透過を保持するため PNG で送る
        let cutoutData = cutoutImage?.pngData()

        let fashionReviewRequest = FashionReviewRequest(user_id: uid, user_token: uid, file: jpegData, tops_image: topsData, bottoms_image: bottomsData, cutout_image: cutoutData)
        let requestParameters: [String: Any] = fashionReviewRequest.createParameters()
        let (headers, body) = HTTP.createMultiPartPost(parameters: requestParameters)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // ヘッダーの設定
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        // Bodyの設定
        request.httpBody = body

        do {
            // URLSessionでリクエストを送信
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            
            // ステータスコードをチェック
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }

            // JSONレスポンスをデコード
            do {
                let response = try JSONDecoder().decode(FashionReviewResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

extension FashionReviewClient {
    func fetchResult(coordinateId: String, uid: String) async throws -> Result<FashionReviewResponse, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        var components = URLComponents(string: "\(baseURL)/api/fashion_review/\(coordinateId)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.badRequest) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(FashionReviewResponse.self, from: data)
                return .success(response)
            } catch {
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockFashionReviewClient: FashionReviewClientProtocol {
    func post(uid: String, image: UIImage, topsImage: UIImage?, bottomsImage: UIImage?, cutoutImage: UIImage?, purposeNum: Int?) async throws -> Result<FashionReviewResponse, HTTPError> {
        return .success(.mock())
    }

    func fetchResult(coordinateId: String, uid: String) async throws -> Result<FashionReviewResponse, HTTPError> {
        return .success(.mock())
    }
}
