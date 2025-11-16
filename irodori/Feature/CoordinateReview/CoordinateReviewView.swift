//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    @State var viewModel: CoordinateReviewViewModel

    private let shortTextCriterion = 50
    @State private var currentSchedule = ""   // YYYY/MM/DD
    @State private var reviewText = ""
    @State private var isShowFullReview = false
    @State private var tappedURL = ""
    @State private var isPresentedCameraView = false
    @State private var tappedAffiliateProduct: AffiliateProduct?
    @Binding var path: [ViewType]


    var body: some View {
        ZStack {
            if let fashionReview = viewModel.fashionReview {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        LargeCoordinateCard(
                            coordinateImage: viewModel.coordinateImage,
                            currentSchedule: viewModel.currentDateString,
                            aiCatchphrase: viewModel.fashionReview!.ai_catchphrase,
                            tags: nil   // タグ非表示
                        )
                        if let tags = viewModel.fashionReview?.tags, !tags.isEmpty {
                            TagsView(tags: tags, backgroundMaterial: .thinMaterial, tagTextColor: .black, borderColor: .black)
                                .padding(.horizontal, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        RecentCoordinates(recentCoordinates: viewModel.fashionReview!.recent_coordinates)   // TODO: - 直近のコーデがない場合のUIを考える & 直近のコーデをVMで管理する
                        VStack(alignment: .leading, spacing: 12) {
                            Image(.wolf)
                                .resizable()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                            ReviewText(aiReviewComment: viewModel.fashionReview!.ai_review_comment)
                        }
                        .padding(.horizontal, 24)
                        CoordinateItems(topsUIImage: viewModel.topsUIImage, bottomsUIImage: viewModel.bottomsUIImage)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50 + 12 + 12)   // ButtonHeight + ButtonBottomPadding + BottomPadding
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            path.removeAll()
                        }, label: {
                            Text("ホームへ")
                        })
                    }
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
                .navigationDestination(isPresented: $isPresentedCameraView) {
                    CameraView()
                }
                .background(.gray.opacity(0.08))
                .navigationBarBackButtonHidden()
            } else {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                    Text("レビュー作成中...")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.pink)
                    Text("作成に8〜10秒ほど時間がかかります")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.pink.opacity(0.5))
                    }
                    Image(.splash03)
                        .resizable()
                        .frame(width: 200, height: 300)
                }
                .navigationBarBackButtonHidden()
            }

            if let errorMessage = viewModel.errroMessage {
                ErrorMessageView(errorMessage: errorMessage) {
                    path.removeAll()   // カメラ画面へ戻る
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    private func RecommendCoordinateCard(imageURL: String) -> some View {
        ZStack {
            CachedAsyncImage(url: URL(string: imageURL)!) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    Color.red
                } else {
                    Color.gray.opacity(0.5)
                }
            }
            .frame(width: 110, height: 110 * (4/3))
        }
        .background(.white)
    }
}

#Preview {
    CoordinateReviewView(viewModel: .init(
        coordinateImage: UIImage(resource: .coordinate2),
        apiClient: MockFashionReviewClient()
    ), path: .constant([]))
}
