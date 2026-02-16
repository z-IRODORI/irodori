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

    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var authRetryCount = 0

    init(path: String, storageClient: FirebaseStorageClientProtocol = FirebaseStorageClient()) {
        self.path = path
        self.storageClient = storageClient

        // 初期化時に画像キャッシュをチェック
        if let cachedImage = UIImageCache.shared.getImage(for: path) {
            _uiImage = State(initialValue: cachedImage)
            _isLoading = State(initialValue: false)
        }
    }

    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
        .task(id: path) {
            await loadImage()
        }
    }

    private var placeholderView: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
//            .foregroundStyle(.gray)
            .padding()
    }

    private func loadImage() async {
        // 画像キャッシュチェック（同期的に実行）
        if let cachedImage = UIImageCache.shared.getImage(for: path) {
            self.uiImage = cachedImage
            self.isLoading = false
            self.error = nil
            return
        }

        // キャッシュがない場合のみローディング表示
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
            // URLキャッシュをチェック
            let url: URL
            if let cachedURL = ImageURLCache.shared.getURL(for: path) {
                url = cachedURL
            } else {
                url = try await storageClient.getDownloadURL(for: path)
                ImageURLCache.shared.setURL(url, for: path)
            }

            // 画像をダウンロード
            let (data, _) = try await URLSession.shared.data(from: url)
            if let downloadedImage = UIImage(data: data) {
                self.uiImage = downloadedImage
                self.error = nil
                // 画像をキャッシュに保存
                UIImageCache.shared.setImage(downloadedImage, for: path)
            } else {
                self.error = NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
            }
        } catch {
            self.error = error
        }
    }
}
