//
//  CachedAsyncImage.swift
//  irodori
//
//  Created by Claude on 2025/09/29.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            case .success(let image):
                content(image)
            case .failure:
                placeholder()
            @unknown default:
                placeholder()
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            phase = .failure(URLError(.badURL))
            return
        }
        
        // Check cache
        if let cachedImage = ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        // Load from network
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        ImageCache.shared.insertImage(uiImage, for: url)
                        phase = .success(Image(uiImage: uiImage))
                    }
                } else {
                    await MainActor.run {
                        phase = .failure(URLError(.cannotDecodeContentData))
                    }
                }
            } catch {
                await MainActor.run {
                    phase = .failure(error)
                }
            }
        }
    }
}

// Simple in-memory image cache
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Limit to 100 images
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    func insertImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL, cost: image.pngData()?.count ?? 0)
    }
    
    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    func removeAllImages() {
        cache.removeAllObjects()
    }
}