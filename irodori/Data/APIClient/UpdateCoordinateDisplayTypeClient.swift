//
//  UpdateCoordinateDisplayTypeClient.swift
//  irodori
//
//  コーデの一覧表示に使う画像種別 (撮影 / 切り取り) を切り替える。
//  POST /api/coordinate/{id}/display-type?display_type=captured|cutout
//

import Foundation

protocol UpdateCoordinateDisplayTypeClientProtocol {
    func update(coordinateId: String, displayType: String) async throws -> Result<Void, HTTPError>
}

final class UpdateCoordinateDisplayTypeClient: UpdateCoordinateDisplayTypeClientProtocol {
    func update(coordinateId: String, displayType: String) async throws -> Result<Void, HTTPError> {
        let baseURL = "https://irodori-api.onrender.com"
        guard let encoded = coordinateId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "\(baseURL)/api/coordinate/\(encoded)/display-type") else {
            return .failure(.responseError)
        }
        components.queryItems = [URLQueryItem(name: "display_type", value: displayType)]
        guard let url = components.url else { return .failure(.responseError) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (_, urlResponse) = try await URLSession.shared.data(for: request)
            if let httpResponse = urlResponse as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                return .failure(HTTPError.fromStatusCode(httpResponse.statusCode))
            }
            return .success(())
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw CancellationError()
            }
            return .failure(.responseError)
        }
    }
}

// MARK: - Mock

final class MockUpdateCoordinateDisplayTypeClient: UpdateCoordinateDisplayTypeClientProtocol {
    func update(coordinateId: String, displayType: String) async throws -> Result<Void, HTTPError> {
        return .success(())
    }
}
