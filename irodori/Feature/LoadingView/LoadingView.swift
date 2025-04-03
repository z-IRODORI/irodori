//
//  LoadingView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/03.
//

import SwiftUI
import Kingfisher

enum LoadingState {
    case initial
    case loading
    case success(Bool, String)
    case failure(String)   // TODO: エラーハンドリング
}

struct LoadingView: View {

    let client: GPTClient = .init()
    @State private var isFinishedRequest = false
    @State private var reviewText = ""

    let coordinateImage: UIImage
    init(coordinateImage: UIImage) {
        self.coordinateImage = coordinateImage
    }

    private let loadingGIFURL = URL(string: "https://cdn.pixabay.com/animation/2024/07/27/09/34/09-34-07-906_512.gif")!

    var body: some View {
        VStack(spacing: 48) {
            Text("レビューコメント生成中...")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.gray)
            KFAnimatedImage(loadingGIFURL)
                .frame(width: 100 * 2, height: 80 * 2)
                .scaledToFit()

            if isFinishedRequest {
                Text(reviewText)
            }
        }
        .onAppear {
            Task {
                let result = try await client.postImageToGPT(image: coordinateImage)
                isFinishedRequest = true
                await MainActor.run {
                    reviewText = result
                    isFinishedRequest = true
                }
            }
        }
        .navigationDestination(isPresented: $isFinishedRequest) {
            CoordinateReviewView(
                coordinateImage: coordinateImage,
                coordinateReview: .init(id: 1, coordinateReview: reviewText, recommend: [])
            )
        }
    }
}

#Preview {
    LoadingView(
        coordinateImage: UIImage(resource: .coordinate1)
    )
}
