//
//  HTTP.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/30.
//

import Foundation

struct HTTP {
    static func createMultiPartPost(parameters: [String: Any]) -> (headers: [String:String], body: Data) {
        let uniqueId = UUID().uuidString
        let boundary = "---------------------------\(uniqueId)"

        let header = [
            "Content-Type" : "multipart/form-data; boundary=\(boundary)"
        ]

        var body = Data()

        let boundaryText = "--\(boundary)\r\n"

        for param in parameters {
            switch param.value {
            case let imageData as Data:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"; filename=\"\(uniqueId).jpg\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(imageData)
                body.append("\r\n".data(using: .utf8)!)
            case let string as String:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(string.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            case let value as Any:
                body.append(boundaryText.data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(param.key)\"\r\n\r\n".data(using: .utf8)!)
                body.append(String(describing: value).data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return (header, body)
    }
}
