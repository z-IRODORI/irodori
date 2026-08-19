//
//  AnalysisJobClient.swift
//  irodori
//
//  v2 コーデ解析のバックグラウンドジョブ (常駐トースター UX)。
//  submit で即 job_id を受け取り、status をポーリングする。
//

import UIKit

protocol AnalysisJobClientProtocol {
    func submit(uid: String, image: UIImage, cutoutImage: UIImage?) async throws -> Result<AnalysisJobResponse, HTTPError>
    func status(jobId: String, uid: String) async throws -> Result<AnalysisJobResponse, HTTPError>
}

final class AnalysisJobClient: AnalysisJobClientProtocol {
    private let baseURL = "https://irodori-api.onrender.com"

    func submit(uid: String, image: UIImage, cutoutImage: UIImage?) async throws -> Result<AnalysisJobResponse, HTTPError> {
        let url = URL(string: "\(baseURL)/api/analysis-jobs")!

        guard let jpegData = image.jpegData(compressionQuality: 0.5) else {
            return .failure(.badRequest)
        }

        var parameters: [String: Any] = [
            "user_id": uid,
            "user_token": uid,
            "file": jpegData,
        ]
        // 人物切り取りは背景透過を保持するため PNG で送る
        if let cutoutData = cutoutImage?.pngData() {
            parameters["cutout_image"] = cutoutData
        }
        let (headers, body) = HTTP.createMultiPartPost(parameters: parameters)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        request.httpBody = body

        return await send(request)
    }

    func status(jobId: String, uid: String) async throws -> Result<AnalysisJobResponse, HTTPError> {
        var components = URLComponents(string: "\(baseURL)/api/analysis-jobs/\(jobId)")!
        components.queryItems = [URLQueryItem(name: "user_id", value: uid)]
        guard let url = components.url else { return .failure(.badRequest) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return await send(request)
    }

    private func send(_ request: URLRequest) async -> Result<AnalysisJobResponse, HTTPError> {
        do {
            let (data, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode >= 400 {
                    return .failure(HTTPError.fromStatusCode(statusCode))
                }
            }
            do {
                let response = try JSONDecoder().decode(AnalysisJobResponse.self, from: data)
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

final class MockAnalysisJobClient: AnalysisJobClientProtocol {
    func submit(uid: String, image: UIImage, cutoutImage: UIImage?) async throws -> Result<AnalysisJobResponse, HTTPError> {
        .success(.init(job_id: "mock-job", status: "processing",
                       coordinate_id: nil, coordinate_image_path: nil, error: nil))
    }

    func status(jobId: String, uid: String) async throws -> Result<AnalysisJobResponse, HTTPError> {
        .success(.init(job_id: jobId, status: "completed",
                       coordinate_id: "mock-coordinate",
                       coordinate_image_path: "https://images.wear2.jp/coordinate/bBildLXx/yMN071qf/1752555537_1000.jpg",
                       error: nil))
    }
}
