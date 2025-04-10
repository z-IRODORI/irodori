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
    @State private var coordinateReview: CoordinateReview = .mock()
    @State private var fashionGraphImage: UIImage = .init()
    @State private var predictResponse: PredictResponse = .init(graph_image: "", similar_wear: [])

    let coordinateImage: UIImage
    let tag: OutingPurposeType
    init(coordinateImage: UIImage, tag: OutingPurposeType) {
        self.coordinateImage = coordinateImage
        self.tag = tag
    }

    private let loadingGIFURL = URL(string: "https://cdn.pixabay.com/animation/2024/07/27/09/34/09-34-07-906_512.gif")!

    var body: some View {
        VStack(spacing: 48) {
            Text("レビューコメント生成中...")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.gray)
            Text("※ コメント生成に 30秒ほど 時間かかります...")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.gray)

            KFAnimatedImage(loadingGIFURL)
                .frame(width: 100 * 2, height: 80 * 2)
                .scaledToFit()
        }
        .onAppear {
            Task {
                // GPT (port5000)
                guard let response1: CoordinateReview = try await client.postImageToGPT(image: coordinateImage, outingPurposeType: tag) else { return }
                print(response1)
                // SearchMyFashon (port8000)
                let searchMyFashionClient: SerchMyFashionClient = .init()
                guard let response2: PredictResponse = try await searchMyFashionClient.postImage(image: coordinateImage.correctOrientation) else { return }
                predictResponse = response2

                await MainActor.run {
                    coordinateReview = response1
                    isFinishedRequest = true

                    guard let imageData = Data(base64Encoded: response2.graph_image) else { return }
                    fashionGraphImage = UIImage(data: imageData)!
                }
            }
        }
        .navigationDestination(isPresented: $isFinishedRequest) {
            CoordinateReviewView(
                coordinateImage: coordinateImage,
                coordinateReview: coordinateReview,
                predictResponse: predictResponse
            )
        }
    }
}

#Preview {
    LoadingView(
        coordinateImage: UIImage(resource: .coordinate1),
        tag: .nothing
    )
}
