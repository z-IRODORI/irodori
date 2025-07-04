//
//  HTTPErrorTests.swift
//  irodoriTests
//
//  Created by Claude on 2025/07/04.
//

import XCTest
@testable import irodori

final class HTTPErrorTests: XCTestCase {
    
    func testHTTPErrorInitialization() {
        XCTAssertEqual(HTTPError(statusCode: 401), .unauthorized)
        XCTAssertEqual(HTTPError(statusCode: 403), .forbidden)
        XCTAssertEqual(HTTPError(statusCode: 404), .notFound)
        XCTAssertEqual(HTTPError(statusCode: 500), .internalServerError)
        XCTAssertEqual(HTTPError(statusCode: 999), .unknown(999))
    }
    
    func testHTTPErrorMessages() {
        XCTAssertEqual(HTTPError.unauthorized.title, "認証エラー")
        XCTAssertEqual(HTTPError.notFound.title, "見つかりません")
        XCTAssertEqual(HTTPError.networkError.title, "ネットワークエラー")
        
        XCTAssertTrue(HTTPError.unauthorized.message.contains("認証情報"))
        XCTAssertTrue(HTTPError.networkError.message.contains("ネットワーク接続"))
    }
    
    func testLocalizedError() {
        let error = HTTPError.unauthorized
        XCTAssertEqual(error.errorDescription, error.message)
        XCTAssertEqual(error.failureReason, error.title)
    }
}