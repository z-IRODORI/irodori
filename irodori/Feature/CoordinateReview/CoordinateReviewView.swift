//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    @State var viewModel: CoordinateReviewViewModel

    let fromFirstTakePhotoView: Bool
    private let shortTextCriterion = 50
    @State private var currentSchedule = ""   // YYYY/MM/DD
    @State private var reviewText = ""
    @State private var isShowFullReview = false
    @State private var tappedURL = ""
    @State private var tappedAffiliateProduct: AffiliateProduct?
    @State private var hasCalledSetupFirstTakePhoto = false
    /// タップされたアイテム (詳細シート表示用)
    @State private var selectedItem: FashionReviewResponse.Item?
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
                            tags: viewModel.fashionReview?.tags   // タグ非表示
                        )
//                        if let tags = viewModel.fashionReview?.tags, !tags.isEmpty {
//                            TagsView(tags: tags, backgroundMaterial: .thinMaterial, tagTextColor: .black, borderColor: .black)
//                                .padding(.horizontal, 24)
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                        }
                        RecentCoordinates(
                            recentCoordinates: viewModel.fashionReview!.recent_coordinates,
                            isEditMode: false,
                            onToggleEditMode: {},
                            onDeleteRequest: { _ in },
                            onTapCoordinate: { _ in }
                        )
                        VStack(alignment: .leading, spacing: 12) {
                            PartnerIconImage(size: 50)
                            ReviewText(aiReviewComment: viewModel.fashionReview!.ai_review_comment)
                        }
                        .padding(.horizontal, 24)
                        let detectedItems = viewModel.fashionReview?.items ?? []
                        // v2 はサーバー生成の透過アイテム画像 URL (items/{uid}/generated/) が入る。
                        // エンジン設定でなくレスポンス内容で判定する (トグル変更に影響されない)
                        let hasGeneratedItems = detectedItems.contains { $0.item_image_path.contains("/generated/") }
                        CoordinateItems(
                            topsUIImage: viewModel.topsUIImage,
                            bottomsUIImage: viewModel.bottomsUIImage,
                            serverItems: detectedItems,
                            useServerItems: hasGeneratedItems,
                            onTapItem: { item in selectedItem = item }
                        )
                            .padding(.horizontal, 24)
                            .padding(.bottom, detectedItems.isEmpty ? 50 + 12 + 12 : 0)   // ButtonHeight + ButtonBottomPadding + BottomPadding
                        // 検出したアイテムごとに、ネットで見つけた「きれいな画像」を横並びで提示する
                        // (ユーザーに見せる検索ワードは検出結果のまま。検索時のみ「ユニクロ」が付く)
                        if !detectedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(detectedItems, id: \.id) { item in
                                    WebItemImagesRow(
                                        searchWord: item.webImageSearchWord,
                                        typeLabel: item.item_type
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 50 + 12 + 12)   // ButtonHeight + ButtonBottomPadding + BottomPadding
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            AnalyticsLogger.shared.log(action: .coordinateReviewed, parameters: [
                                "action": GAEventAction.goHome.rawValue
                            ])
                            path.removeAll()
                        }, label: {
                            Text("ホームへ")
                        })
                    }
                }
                .overlay(alignment: .bottom) {
                    Button(action: {
                        AnalyticsLogger.shared.log(action: .recommendationRequested, parameters: [
                            "source": GAEventAction.coordinateReview.rawValue
                        ])
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
                // アイテム詳細 (カテゴリ/カラー/名前/特徴 + このアイテムを使ったコーデ)
                .sheet(item: $selectedItem) { item in
                    ItemDetailSheet(
                        itemId: item.id,
                        initialImageURL: item.item_image_path,
                        initialTypeLabel: item.item_type
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(.gray.opacity(0.08))
                .navigationBarBackButtonHidden()
            } else {
                CoordinateReviewLoadingView(
                    coordinateImage: viewModel.coordinateImage,
                    topsImage: viewModel.topsUIImage,
                    bottomsImage: viewModel.bottomsUIImage,
                    topsRect: viewModel.topsBoundingRect,
                    bottomsRect: viewModel.bottomsBoundingRect
                )
                .navigationBarBackButtonHidden()
            }

            if let errorMessage = viewModel.errroMessage {
                ErrorMessageView(errorMessage: errorMessage) {
                    path.removeAll()   // カメラ画面へ戻る
                }
            }
        }
        .task {
            AnalyticsLogger.shared.log(screen: .coordinateReviewScreenView)
            await viewModel.onAppear(allowBackgroundJob: !fromFirstTakePhotoView)
        }
        // v2: ジョブ送信が完了したら抽出画面を閉じてホームへ戻る (常駐トースターに引き継ぎ)
        .onChange(of: viewModel.didSubmitBackgroundJob) { _, submitted in
            if submitted { path.removeAll() }
        }
        .onChange(of: viewModel.fashionReview) { _, newValue in
            // 分析結果が表示されたタイミングで setupFirstTakePhotoIfNeeded を呼び出す
            if fromFirstTakePhotoView && newValue != nil && !hasCalledSetupFirstTakePhoto {
                viewModel.setupFirstTakePhotoIfNeeded()
                hasCalledSetupFirstTakePhoto = true
            }
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
    CoordinateReviewView(
        viewModel: .init(
            coordinateImage: UIImage(resource: .coordinate2),
            apiClient: MockFashionReviewClient()
        ),
        fromFirstTakePhotoView: false,
        path: .constant([])
    )
}
