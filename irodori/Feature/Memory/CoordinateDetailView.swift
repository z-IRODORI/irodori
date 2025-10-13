//
//  CoordinateDetailView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

struct CoordinateDetailView: View {
    @State var viewModel: CoordinateDetailViewModel

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
                viewModel.tappedRecommendCoordinateButton()
            }) {
                Text("おすすめのコーデ/アイテムを見る")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.gray.opacity(0.08))
        .task {
            await viewModel.onAppear()
        }
    }
}
