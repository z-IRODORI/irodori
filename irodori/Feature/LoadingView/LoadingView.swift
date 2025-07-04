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

    private let fashionReviewService: FashionReviewService = .init()
    @State private var isFinishedRequest = false
    @State private var fashionReview: FashionReviewResponse = .init(createdAt: "", tops_image_url: "", bottoms_image_url: "", coordinate: .mock(), graph_image: "", recommendations: [])

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
                do {
                    let result = try await fashionReviewService.submitFashionReview(
                        userId: UUID().uuidString,
                        userToken: UUID().uuidString,
                        image: coordinateImage.correctOrientation,
                        days: 7
                    )
                    
                    switch result {
                    case .success(let apiResponse):
                        // Convert APIFashionReviewResponse to legacy FashionReviewResponse
                        let legacyResponse = FashionReviewResponse(
                            createdAt: nil,
                            tops_image_url: "",
                            bottoms_image_url: "",
                            coordinate: FashionReviewResponse.Coordinate(
                                coordinate_review: apiResponse.ai_comment,
                                coordinate_item01: apiResponse.items.first?.item_type ?? "",
                                recommend_item01: "",
                                coordinate_item02: apiResponse.items.count > 1 ? apiResponse.items[1].item_type : "",
                                recommend_item02: "",
                                coordinate_item03: apiResponse.items.count > 2 ? apiResponse.items[2].item_type : "",
                                recommend_item03: ""
                            ),
                            graph_image: apiResponse.current_coordinate.coodinate_image_path,
                            recommendations: []
                        )
                        
                        await MainActor.run {
                            self.fashionReview = legacyResponse
                            isFinishedRequest = true
                        }
                    case .failure(let error):
                        print("Error: \(error)")
                        await MainActor.run {
                            dismiss()
                        }
                    }
                } catch {
                    print("Error: \(error)")
                    await MainActor.run {
                        dismiss()
                    }
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
