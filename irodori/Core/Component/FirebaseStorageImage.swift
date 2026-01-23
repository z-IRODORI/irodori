//
//  FirebaseStorageImage.swift
//  irodori
//
//  Created by Claude Code on 2026/01/22.
//

import SwiftUI
import FirebaseAuth

struct FirebaseStorageImage: View {
    let path: String
    let storageClient: FirebaseStorageClientProtocol

    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var authRetryCount = 0

    init(path: String, storageClient: FirebaseStorageClientProtocol = FirebaseStorageClient()) {
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
                    case .failure(let error):
                        VStack {
                            placeholderView
                            Text("画像読み込みエラー")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if error != nil {
                VStack(spacing: 4) {
                    placeholderView
                    Text("読み込み失敗")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            .padding()
    }

    private func loadImageURL() async {
        isLoading = true
        defer { isLoading = false }

        // 認証チェック（最大3回リトライ）
        while authRetryCount < 3 {
            if Auth.auth().currentUser != nil {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            authRetryCount += 1
        }

        do {
            let url = try await storageClient.getDownloadURL(for: path)
            self.imageURL = url
            self.error = nil
        } catch {
            self.error = error
        }
    }
}
