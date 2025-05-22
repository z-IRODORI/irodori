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
    @Environment(\.dismiss) private var dismiss

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
            VStack(spacing: 12) {
                Text("レビューコメント生成中...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.gray)
                Text("※ コメント生成に 20秒ほど 時間かかります...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.gray)
            }

            KFAnimatedImage(loadingGIFURL)
                .frame(width: 100 * 2, height: 80 * 2)
                .scaledToFit()
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            Task {
                // GPT (port5000)
                async let response1: Result<CoordinateReview, Error> = client.postImageToGPT(image: coordinateImage, outingPurposeType: tag)
                // SearchMyFashon (port8000)
                let searchMyFashionClient: SerchMyFashionClient = .init()
                async let response2: Result<PredictResponse, Error> = searchMyFashionClient.postImage(image: coordinateImage.correctOrientation)

                // 両方の結果を await で待つ. ここで最も遅いタスクの完了を待つことになります
                let apiResponse1 = try await response1
                let apiResponse2 = try await response2

                switch (apiResponse1, apiResponse2) {
                case (.failure(let error), _), (_, .failure(let error)):
                    print("Error: \(error)")
                    dismiss()
                    return
                case (.success(let response1), .success(let response2)):
                    await MainActor.run {
                        coordinateReview = response1
                        predictResponse = response2
                        isFinishedRequest = true

                        guard let imageData = Data(base64Encoded: response2.graph_image) else { return }
                        fashionGraphImage = UIImage(data: imageData)!
                    }
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
