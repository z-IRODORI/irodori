//
//  FirebaseStorageClient.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import Foundation
import FirebaseStorage

protocol FirebaseStorageClientProtocol {
    func getDownloadURL(for path: String) async throws -> URL
}

final class FirebaseStorageClient: FirebaseStorageClientProtocol {
    private let storage = Storage.storage()

    func getDownloadURL(for path: String) async throws -> URL {
        let storageRef = storage.reference()

        // NFD形式で試行
        let nfdPath = path.decomposedStringWithCanonicalMapping
        let cleanNfdPath = nfdPath.hasPrefix("/") ? String(nfdPath.dropFirst()) : nfdPath

        do {
            let fileRef = storageRef.child(cleanNfdPath)
            let url = try await fileRef.downloadURL()
            return url
        } catch let nfdError as NSError {
            // NFDで失敗した場合、NFC形式でリトライ
            if nfdError.code == -13010 {
                let nfcPath = path.precomposedStringWithCanonicalMapping
                let cleanNfcPath = nfcPath.hasPrefix("/") ? String(nfcPath.dropFirst()) : nfcPath

                let fileRef = storageRef.child(cleanNfcPath)
                let url = try await fileRef.downloadURL()
                return url
            } else {
                throw nfdError
            }
        }
    }
}
