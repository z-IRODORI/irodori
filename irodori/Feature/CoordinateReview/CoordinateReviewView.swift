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
                            aiCatchphrase: viewModel.fashionReview!.ai_catchphrase
                        )
                        RecentCoordinates()   // TODO: - 直近のコーデがない場合のUIを考える & 直近のコーデをVMで管理する
                        ReviewText(aiReviewComment: viewModel.fashionReview!.ai_review_comment)
                            .padding(.horizontal, 24)
                        RecommendCoordinates()
                        CoordinateItems()
                            .padding(.horizontal, 24)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: tappedURL) {
                    let url = URL(string: tappedURL)!   // TODO: エラーハンドリング
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
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
        .sheet(isPresented: $viewModel.isShowingWebView) {
            if let url = URL(string: viewModel.webURLString) {
                WebViewContainer(url: url)
            } else {
                // TODO: エラー画面実装
                Text("無効なURLです")
                    .foregroundStyle(.red)
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }

    private func RecentCoordinates() -> some View {
        VStack(spacing: 12) {
            Text("直近のコーデ")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            if viewModel.fashionReview!.recent_coordinates.isEmpty {
                Text("コーデが存在しません...")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 12)

                        ForEach(viewModel.fashionReview!.recent_coordinates, id: \.self) { fashionReview in
                            RecentCoordinateCard(
                                imageURL: fashionReview.coodinate_image_path,
                                text: fashionReview.date
                            )
                        }
                    }
                }
            }
        }
    }

    private func CoordinateItems() -> some View {
        VStack(spacing: 12) {
            Text("着用しているアイテム")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CoordinateItemCard(
                        uiImage: viewModel.topsUIImage,
                        text: "トップス", textColor: .black
                    )

                    CoordinateItemCard(
                        uiImage: viewModel.bottomsUIImage,
                        text: "ボトムス", textColor: .black
                    )

                    // APIレスポンスからデータ受け取れるようになったら使う
//                    ForEach(viewModel.fashionReview!.items, id: \.self) { item in
//                        CoordinateItemCard(
//                            imageURL: item.item_image_path,
//                            text: item.item_type, textColor: .black
//                        )
//                    }
                }
            }
        }
    }

    private func RecommendCoordinates() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("これまでのコーデからおすすめコーデ")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            switch viewModel.recommendCoordinatesState {
            case .loading, .initial:
                ProgressView()
                    .padding(.leading, 24)
            case .loaded(let recommendCoordinates):
                VStack(spacing: 24) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            // 左端に24pxの空白を空けたいのでSpacerで表現
                            // スクロールすると空白は消えてほしいのでpaddingではなくSpacer
                            Spacer().frame(width: 24)
                            ForEach(recommendCoordinates.coordinates, id: \.self) { recommendCoordinate in
                                CachedAsyncImage(url: .init(string: recommendCoordinate.image_url)) { phase in
                                    if let image = phase.image {
                                        image.resizable()
                                            .onTapGesture {
                                                viewModel.setSelectedRecommendCoordinate(coordinate: recommendCoordinate)
                                            }
                                    } else if phase.error != nil {
                                        Color.red
                                    } else {
                                        Color.gray.opacity(0.5)
                                    }
                                }
                                .frame(width: 120, height: 120 * 1.38)   // 1:1.38
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            }
                            Spacer().frame(width: 24)
                        }
                    }
                    .frame(height: 110 * (4/3))

                    AffiliateItems(title: "トップス", affiliateProducts: viewModel.selectedRecommendCoordinate.affiliate_tops)
                    AffiliateItems(title: "ボトムス", affiliateProducts: viewModel.selectedRecommendCoordinate.affiliate_bottoms)
                }
            case .failed(_):
                Button(action: {
                    // action
                }, label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                })
                .padding(.leading, 24)
            }
        }
    }

    private func RecentCoordinateCard(imageURL: String, text: String, _ textColor: Color = .secondary) -> some View {
        VStack(spacing: 0) {

            CachedAsyncImage(url: URL(string: imageURL)!) { phase in
                if let image = phase.image {
                    image.resizable()
                } else if phase.error != nil {
                    Color.red
                } else {
                    Color.gray.opacity(0.5)
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .frame(width: 110)

            Text("\(text)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.vertical, 10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    // コーデアイテム抽出をローカルで実行しているためuiImageを渡している
    // TODO: - コーデアイテム抽出をサーバーで実行可能になった時、このコンポーネントを削除
    private func CoordinateItemCard(uiImage: UIImage?, text: String, textColor: Color = .secondary) -> some View {
        VStack(spacing: 0) {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .padding(12)
            } else {
                ProgressView()
            }

            Text("\(text)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.vertical, 10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// アフェリエイトの商品を横並びに表示する
    ///
    /// 商品の表示サイズは width: 100, height: 100
    /// 商品をタップすると viewModel.setWebViewURLString(url: String) を呼び出し、WebViewを表示する
    private func AffiliateItems(title: String?, affiliateProducts: [AffiliateProduct]) -> some View {
        VStack(spacing: 12) {
            if let title {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 左端に24pxの空白を空けたいのでSpacerで表現
                    // スクロールすると空白は消えてほしいのでpaddingではなくSpacer
                    Spacer().frame(width: 24)
                    ForEach(affiliateProducts, id: \.self) { affiliateProduct in
                        VStack(spacing: 12) {
                            // 商品画像
                            CachedAsyncImage(url: .init(string: affiliateProduct.image_url)) { phase in
                                if let image = phase.image {
                                    image.resizable()
                                    .onTapGesture {
                                        viewModel.setWebViewURLString(url: affiliateProduct.url)
                                    }
                                } else if phase.error != nil {
                                    Color.red
                                } else {
                                    Color.gray.opacity(0.5)
                                }
                            }
                            .frame(width: 120, height: 120)

                            // 販売店, 価格
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(affiliateProduct.store_name)")
                                    .lineLimit(2)
                                    .font(.system(size: 10, weight: .semibold))
                                Text("¥\(affiliateProduct.price)")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.bottom, 12)
                            .padding(.horizontal, 12)
                        }
                        .frame(width: 120, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .background(.white)
                    }
                    Spacer().frame(width: 24)
                }
            }
        }
    }
}

#Preview {
    CoordinateReviewView(viewModel: .init(
        coordinateImage: UIImage(resource: .coordinate2),
        apiClient: MockFashionReviewClient(),
        recommendCoordinateClient: MockRecommendCoordinateClient()
    ), path: .constant([]))
}
