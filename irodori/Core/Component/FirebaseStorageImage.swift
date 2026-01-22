//
//  FirebaseStorageImage.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import SwiftUI

struct FirebaseStorageImage: View {
    let path: String
    let storageClient: FirebaseStorageClientProtocol

    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var error: Error?

    init(path: String, storageClient: FirebaseStorageClientProtocol = MockFirebaseStorageClient()) {
        self.path = path
        self.storageClient = storageClient
    }

    var body: some View {
        Group {
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderView
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholderView
            }
        }
        .task {
            await loadImageURL()
        }
    }

    private var placeholderView: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadImageURL() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let url = try await storageClient.getDownloadURL(for: path)
            self.imageURL = url
        } catch {
            self.error = error
            print("Failed to load image from Firebase Storage: \(error)")
        }
    }
}
