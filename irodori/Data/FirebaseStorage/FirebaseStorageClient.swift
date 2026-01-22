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
        let fileRef = storageRef.child(path)

        do {
            let url = try await fileRef.downloadURL()
            return url
        } catch {
            print("Firebase Storage error for path \(path): \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Mock

final class MockFirebaseStorageClient: FirebaseStorageClientProtocol {
    func getDownloadURL(for path: String) async throws -> URL {
        // モック用: プレースホルダー画像を返す
        let urlString = "https://picsum.photos/200/200?random=\(path.hashValue)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        return url
    }
}
