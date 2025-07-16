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
    @State private var fashionReview: FashionReviewResponse = .mock()

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
                let fashionReviewClient: FashionReviewClient = .init()
                let fashionReviewResponse: Result<FashionReviewResponse, Error> = try await fashionReviewClient.post(
                    uid: UUID().uuidString,
                    image: coordinateImage.correctOrientation,
                    purposeNum: nil//tag.number
                )

                switch fashionReviewResponse {
                case .success(let fashionReview):
                    await MainActor.run {
                        self.fashionReview = fashionReview
                        isFinishedRequest = true
                    }
                case .failure(let error):
                    print("Error: \(error)")
                    dismiss()
                    return
                }
            }
        }
        .navigationDestination(isPresented: $isFinishedRequest) {
            CoordinateReviewView(
                coordinateImage: coordinateImage,
                fashionReview: fashionReview
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
