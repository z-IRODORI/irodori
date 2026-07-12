//
//  CoordinateCollageClient.swift
//  irodori
//
//  コーデコラージュ生成 APIクライアント。
//  複数のコーデ画像 (3枚以上) と背景色を multipart/form-data で送信し、
//  人物を切り抜いて 1 枚に合成したコラージュ画像を取得する。
//

import Foundation

protocol CoordinateCollageClientProtocol {
    func generate(
        userId: String,
        images: [Data],
        backgroundColorHex: String,
        seed: Int?
    ) async throws -> Result<CoordinateCollageResponse, HTTPError>
}

final class CoordinateCollageClient: CoordinateCollageClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func generate(
        userId: String,
        images: [Data],
        backgroundColorHex: String,
        seed: Int?
    ) async throws -> Result<CoordinateCollageResponse, HTTPError> {
        let endpoint = "api/coordinate/collage"
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return .failure(.responseError)
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
        appendField("background_color", backgroundColorHex)
        appendField("response_format", "url")
        if let seed {
            appendField("seed", String(seed))
        }

        for (index, data) in images.enumerated() {
            // PNG (切り取り済み・透過) と JPEG (撮影) が混在するためマジックバイトで判定
            let isPNG = data.starts(with: [0x89, 0x50, 0x4E, 0x47])
            let ext = isPNG ? "png" : "jpg"
            let mime = isPNG ? "image/png" : "image/jpeg"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"images\"; filename=\"coord_\(index).\(ext)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // 合成は人物切り抜き + Pillow 合成のため長め
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 120.0
        let session = URLSession(configuration: config)

        do {
            let (data, urlResponse) = try await session.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            do {
                let response = try JSONDecoder().decode(CoordinateCollageResponse.self, from: data)
                return .success(response)
            } catch {
                print("[CoordinateCollageClient] decode error: \(error)")
                return .failure(.decodeError)
            }
        } catch {
            print(error.localizedDescription)
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockCoordinateCollageClient: CoordinateCollageClientProtocol {
    func generate(
        userId: String,
        images: [Data],
        backgroundColorHex: String,
        seed: Int?
    ) async throws -> Result<CoordinateCollageResponse, HTTPError> {
        try await Task.sleep(nanoseconds: 800_000_000)
        return .success(CoordinateCollageResponse(
            status: "success",
            collage_id: "mock-collage",
            collage_url: "",
            collage_base64: "",
            image_count: images.count,
            elapsed_ms: 800
        ))
    }
}
