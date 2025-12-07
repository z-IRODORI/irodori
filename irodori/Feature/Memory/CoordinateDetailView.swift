//
//  CoordinateDetailView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

struct CoordinateDetailView: View {
    @State var viewModel: CoordinateDetailViewModel
    @State private var coordinateImage: UIImage?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                if let coordinateDetail = viewModel.coordinateDetail {
                    LargeCoordinateCardWithURL(
                        coordinateImageURL: viewModel.coordinateImageURL,
                        currentSchedule: viewModel.targetDateString,
                        aiCatchphrase: coordinateDetail.ai_catchphrase
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        Image(.wolf)
                            .resizable()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        ReviewText(aiReviewComment: coordinateDetail.ai_review_comment)
                    }
                    .padding(.horizontal, 24)

                    // アイテム抽出をサーバーで行うようになったらコメント外す
                    // MLを使うとなぜか重い
    //                CoordinateItems(topsUIImage: viewModel.topsUIImage, bottomsUIImage: viewModel.bottomsUIImage)
    //                    .padding(.horizontal, 24)
    //                    .padding(.bottom, 50 + 12 + 12)   // ButtonHeight + ButtonBottomPadding + BottomPadding
                }
            }
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                AnalyticsLogger.shared.log(action: .recommendationRequested, parameters: [
                    "source": GAEventAction.coordinateDetail.rawValue,
                    "date": viewModel.targetDateString
                ])
//                viewModel.tappedRecommendCoordinateButton()
                viewModel.tappedWillShowChatView()
            }) {
//                Text("おすすめのコーデ/アイテムを見る")
                Text("質問する")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(.pink)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $viewModel.willShowRecommendCoordinateView) {
            RecommendCoordinateView(viewModel: .init(recommendCoordinateClient: RecommendCoordinateClient()))
        }
        .navigationDestination(isPresented: $viewModel.willShowChatView) {
            if let image = coordinateImage {
                ChatView(coordinateId: viewModel.coordinateDetail?.current_coordinate.id ?? UUID().uuidString, image: image)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.08))
        .task {
            AnalyticsLogger.shared.log(screen: .coordinateDetailScreenView, parameters: [
                "date": viewModel.targetDateString
            ])
            await viewModel.onAppear()
            await loadCoordinateImage()
        }
    }
    
    private func loadCoordinateImage() async {
        guard let url = URL(string: viewModel.coordinateImageURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.coordinateImage = image
                }
            }
        } catch {
            print("Failed to load coordinate image: \(error)")
        }
    }
}
