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
    let showHeader: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // fetch 結果に関わらず画像はプレースホルダとして表示する
                LargeCoordinateCardWithURL(
                    coordinateImageURL: viewModel.coordinateImageURL,
                    currentSchedule: viewModel.coordinateDetail?.current_coordinate.date ?? "",
                    aiCatchphrase: viewModel.coordinateDetail?.ai_catchphrase ?? ""
                )

                if let coordinateDetail = viewModel.coordinateDetail {
                    VStack(alignment: .leading, spacing: 12) {
                        PartnerIconImage(size: 50)
                        ReviewText(aiReviewComment: coordinateDetail.ai_review_comment)
                    }
                    .padding(.horizontal, 24)
                } else if viewModel.isLoadingDetail {
                    ProgressView()
                        .padding(.top, 32)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        Text("詳細を取得できませんでした")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Button {
                            Task { await viewModel.fetchCoordinateDetail() }
                        } label: {
                            Text("再試行")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.black)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 32)
                }
            }
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottom) {
            Button(action: {
                AnalyticsLogger.shared.log(action: .recommendationRequested, parameters: [
                    "source": GAEventAction.coordinateDetail.rawValue,
                    "coordinate_id": viewModel.coordinateId
                ])
//                viewModel.tappedRecommendCoordinateButton()
                viewModel.tappedWillShowChatView()
            }) {
//                Text("おすすめのコーデ/アイテムを見る")
                Text("💬 相棒に質問する")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(.black)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if showHeader {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.coordinateDetail?.current_coordinate.date ?? "")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .task {
            AnalyticsLogger.shared.log(screen: .coordinateDetailScreenView, parameters: [
                "coordinate_id": viewModel.coordinateId
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
