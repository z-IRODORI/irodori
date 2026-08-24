//
//  TryOnClient.swift
//  irodori
//
//  試着 API クライアント。顔画像 (JPEG) と参照コーデを multipart で送り、
//  本人の着用イメージ 1 枚を base64 で受け取る。
//  multipart の組み立ては CoordinateCollageClient を踏襲。
//

import Foundation
import UIKit

/// サーバの構造化エラー (irodori-api の _tryon_http が返す detail.code) と対応する。
/// 通信レイヤ由来のときはクライアント側で code を補う。
struct TryOnAPIError: Error, Equatable {
    let code: String       // DISABLED / LIMIT_EXCEEDED / RATE_LIMIT / SAFETY /
                           // FETCH_FAILED / BAD_REQUEST / SERVER /
                           // TIMEOUT / NETWORK / DECODE / CANCELLED
    let message: String

    static let timeout = TryOnAPIError(code: "TIMEOUT", message: "")
    static let network = TryOnAPIError(code: "NETWORK", message: "")
    static let decode = TryOnAPIError(code: "DECODE", message: "")
    static let cancelled = TryOnAPIError(code: "CANCELLED", message: "")
}

/// 生成品質。standard = Lite (約$0.034/枚) / high = 上位モデル (約$0.067/枚、顔の同一性が一段良い)。
/// 初回は standard、「もう一度生成」は high に切り替えてコスパと満足度を両立する。
enum TryOnQuality: String {
    case standard
    case high
}

protocol TryOnClientProtocol {
    func generate(
        userId: String,
        faceImage: Data,
        gender: Gender,
        source: TryOnSource,
        quality: TryOnQuality
    ) async -> Result<TryOnResponse, TryOnAPIError>
}

final class TryOnClient: TryOnClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func generate(
        userId: String,
        faceImage: Data,
        gender: Gender,
        source: TryOnSource,
        quality: TryOnQuality
    ) async -> Result<TryOnResponse, TryOnAPIError> {
        guard let url = URL(string: "\(baseURL)/api/try-on") else {
            return .failure(.network)
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField("user_id", userId)
        appendField("user_token", userId)
        appendField("gender", gender.apiValue)
        appendField("quality", quality.rawValue)

        switch source {
        case .closet(let items):
            appendField("source_type", "closet")
            appendField("item_image_urls", Self.jsonArray(items.map(\.imageURL)))
            appendField("item_labels", Self.jsonArray(items.map(\.label)))
        case .snap(_, let imageURL, let labels):
            appendField("source_type", "snap")
            appendField("snap_image_url", imageURL)
            appendField("item_labels", Self.jsonArray(labels))
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"face_image\"; filename=\"face.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(faceImage)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // 生成は 4〜15 秒程度 + base64 転送のため余裕を持たせる
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 180.0
        let session = URLSession(configuration: config)

        do {
            let (data, urlResponse) = try await session.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(Self.apiError(from: data, statusCode: httpResponse.statusCode))
            }
            do {
                return .success(try JSONDecoder().decode(TryOnResponse.self, from: data))
            } catch {
                print("[TryOnClient] decode error: \(error)")
                return .failure(.decode)
            }
        } catch {
            switch (error as? URLError)?.code {
            case .timedOut: return .failure(.timeout)
            case .cancelled: return .failure(.cancelled)
            default:
                print("[TryOnClient] request error: \(error.localizedDescription)")
                return .failure(.network)
            }
        }
    }

    /// {"detail": {"code": ..., "message": ...}} をデコード。
    /// 失敗時は statusCode から既定 code にフォールバック。
    private static func apiError(from data: Data, statusCode: Int) -> TryOnAPIError {
        struct Envelope: Codable {
            struct Detail: Codable {
                let code: String
                let message: String
            }
            let detail: Detail
        }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return TryOnAPIError(code: envelope.detail.code, message: envelope.detail.message)
        }
        let code: String
        switch statusCode {
        case 429: code = "RATE_LIMIT"
        case 503: code = "DISABLED"
        default: code = "SERVER"
        }
        return TryOnAPIError(code: code, message: "")
    }

    private static func jsonArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

// MARK: - Mock

/// Preview / Sandbox 用。端末内でダミーの試着結果を生成して返す。
final class MockTryOnClient: TryOnClientProtocol {
    var delaySeconds: Double
    var fixedResult: Result<TryOnResponse, TryOnAPIError>?

    init(delaySeconds: Double = 2.0,
         fixedResult: Result<TryOnResponse, TryOnAPIError>? = nil) {
        self.delaySeconds = delaySeconds
        self.fixedResult = fixedResult
    }

    func generate(
        userId: String,
        faceImage: Data,
        gender: Gender,
        source: TryOnSource,
        quality: TryOnQuality
    ) async -> Result<TryOnResponse, TryOnAPIError> {
        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        if Task.isCancelled { return .failure(.cancelled) }
        if let fixedResult { return fixedResult }
        guard let data = Self.placeholderImage().jpegData(compressionQuality: 0.8) else {
            return .failure(.decode)
        }
        return .success(TryOnResponse(
            status: "success",
            image_base64: data.base64EncodedString(),
            mime_type: "image/jpeg",
            model: "mock-\(quality.rawValue)",
            generation_ms: Int(delaySeconds * 1000)
        ))
    }

    /// 3:4 のグラデーション + 人型シルエットのダミー画像
    private static func placeholderImage() -> UIImage {
        let size = CGSize(width: 768, height: 1024)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [UIColor(white: 0.93, alpha: 1).cgColor,
                          UIColor(white: 0.82, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray, locations: nil) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: 0, y: size.height),
                    options: [])
            }
            let symbol = UIImage(systemName: "figure.stand")?
                .withTintColor(UIColor(white: 0.55, alpha: 1), renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: size.width * 0.25, y: size.height * 0.2,
                                    width: size.width * 0.5, height: size.height * 0.6))
            let text = "試着イメージ (Mock)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
                .foregroundColor: UIColor(white: 0.4, alpha: 1),
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                  y: size.height * 0.86),
                      withAttributes: attributes)
        }
    }
}
