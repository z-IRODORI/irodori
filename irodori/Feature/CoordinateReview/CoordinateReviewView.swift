//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    let viewModel: CoordinateReviewViewModel

    private let shortTextCriterion = 50
    @State private var currentSchedule = ""   // YYYY/MM/DD
    @State private var reviewText = ""
    @State private var isShowFullReview = false
    @State private var tappedURL = ""
    @State private var isPresentedCameraView = false
    @State private var tappedAffiliateProduct: AffiliateProduct?
    @State private var isShowingWebView = false
    @Binding var path: [ViewType]


    var body: some View {
        ZStack {
            if let fashionReview = viewModel.fashionReview {
                ZStack {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            Coordinate()
                            RecentCoordinates()   // TODO: - 直近のコーデがない場合のUIを考える & 直近のコーデをVMで管理する
                            ReviewText()
                                .padding(.horizontal, 24)
                            RecommendCoordinates()
//                            AnalysisCoordinateSection()
//                                .padding(.horizontal, 24)
                            CoordinateItems()
                                .padding(.horizontal, 24)
                                .padding(.bottom, 80)
                        }
                    }

                    Button(action: {
                        // action
                    }) {
                        Text("おすすめコーデを見る")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 12)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
//                    .padding(.bottom, 48)
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
        //        .sheet(item: $tappedRecommendItem) { tappedRecommendItem in
        //            WebView(url: URL(string: tappedRecommendItem.itemURL))
        //        }
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
                .task {
                    await viewModel.loadingOnAppear()
                }
                .navigationBarBackButtonHidden()
            }

            if let errorMessage = viewModel.errroMessage {
                ErrorMessageView(errorMessage: errorMessage) {
                    path.removeAll()   // カメラ画面へ戻る
                }
            }
        }
        .sheet(isPresented: $isShowingWebView) {
            if let product = tappedAffiliateProduct {
                AffiliateWebView(
                    url: URL(string: product.url),
                    productName: product.name
                )
            }
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

    private func Coordinate() -> some View {
        ZStack {
            Image(uiImage: viewModel.coordinateImage)
                .resizable()
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.size.height / 2)
                        .position(x: geometry.size.width / 2,
                                  y: geometry.size.height - (geometry.size.height / 4))
                    }
                }
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.3), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .position(x: geometry.size.width / 2, y: 24)
                    }
                }

            Text("\(currentSchedule)")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
            Text("\(viewModel.fashionReview!.ai_catchphrase)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onAppear {
            // TODO: VM に移行
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            dateFormatter.locale = Locale(identifier: "ja_JP")
            let now = Date()
            currentSchedule = dateFormatter.string(from: now)
        }
    }

    private func ReviewText() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIのコーデコメント")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if isShowFullReview {
                Text(.init(viewModel.fashionReview!.ai_review_comment))
                    .font(.system(size: 16, weight: .regular))
            } else {
                VStack(alignment: .leading) {
                    Text(.init("\(viewModel.fashionReview!.ai_review_comment.prefix(shortTextCriterion)) ..."))
                        .font(.system(size: 16, weight: .regular))
                    Button(action: {
                        isShowFullReview = true
                    }) {
                        Text("続きを見る")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .onAppear {
            isShowFullReview = viewModel.fashionReview!.ai_review_comment.count < shortTextCriterion
        }
    }

    private func RecommendCoordinates() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("これまでのコーデからおすすめコーデ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            if let recommendCoordinates = viewModel.recommendCoordinates {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // 左端に24pxの空白を空けたいのでSpacerで表現
                        // スクロールすると空白は消えてほしいのでpaddingではなくSpacer
                        Spacer().frame(width: 24)
                        ForEach(recommendCoordinates.coordinates, id: \.self) { recommendCoordinate in
                            RecommendCoordinateCard(imageURL: recommendCoordinate.image_url)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(viewModel.selectedRecommendCoordinate.id == recommendCoordinate.id ? .green : .clear, lineWidth: 5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    viewModel.selectedRecommendCoordinate(recommendCoordinate: recommendCoordinate)
                                }
                        }
                        Spacer().frame(width: 24)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    private func RecommendItemText(coordinate_item: String, recommend_item: String, recommend_item_url: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
//                tappedURL = recommend_item_url
            }, label: {
                Text("🔍 \(recommend_item)")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            })
            Text("\(coordinate_item)")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func RecentCoordinateCard(imageURL: String, text: String, _ textColor: Color = .secondary) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: URL(string: imageURL)!) { image in
                image
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .frame(width: 110)
            } placeholder: {
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

    private func RecommendCoordinateCard(imageURL: String) -> some View {
        ZStack {
            AsyncImage(url: URL(string: imageURL)!) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110 * (4/3))
            } placeholder: {
                ProgressView()
            }
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
    
    private func AnalysisCoordinateSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アイテム検索")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoadingAnalysisCoordinate {
                // 1. 最優先：ローディング表示
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("アイテムを解析しています...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 2. データ表示の優先度判定
                let hasRecommendAffiliateData = viewModel.selectedRecommendCoordinate.id != 0 && 
                    (!viewModel.selectedRecommendCoordinate.affiliate_tops.isEmpty || 
                     !viewModel.selectedRecommendCoordinate.affiliate_bottoms.isEmpty)
                
                let hasAnalysisData = viewModel.analysisCoordinateResponse != nil &&
                    (!viewModel.analysisCoordinateResponse!.affiliate_tops.isEmpty || 
                     !viewModel.analysisCoordinateResponse!.affiliate_bottoms.isEmpty)
                
                if hasRecommendAffiliateData || hasAnalysisData {
                    // アフィリエイトデータの表示（recommend-coordinatesを優先）
                    AffiliateDataView(
                        shouldShowRecommendData: hasRecommendAffiliateData,
                        recommendCoordinate: viewModel.selectedRecommendCoordinate,
                        analysisResponse: viewModel.analysisCoordinateResponse,
                        onProductTapped: { product in
                            tappedAffiliateProduct = product
                            isShowingWebView = true
                        }
                    )
                } else {
                    // エラーまたは空データ表示
                    Text("アイテム情報の取得に失敗しました")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                }
            }
        }
    }
    
    // アフィリエイトデータ表示用のヘルパーView
    private func AffiliateDataView(
        shouldShowRecommendData: Bool,
        recommendCoordinate: RecommendCoordinate,
        analysisResponse: AnalysisCoordinateResponse?,
        onProductTapped: @escaping (AffiliateProduct) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // データソースを決定
            let (topsCategorize, bottomsCategorize, affiliateTops, affiliateBottoms): 
            (String?, String?, [AffiliateProduct], [AffiliateProduct]) = {
                if shouldShowRecommendData {
                    return (
                        recommendCoordinate.tops_categorize,
                        recommendCoordinate.bottoms_categorize,
                        recommendCoordinate.affiliate_tops,
                        recommendCoordinate.affiliate_bottoms
                    )
                } else if let analysis = analysisResponse {
                    return (
                        analysis.tops_categorize,
                        analysis.bottoms_categorize,
                        analysis.affiliate_tops,
                        analysis.affiliate_bottoms
                    )
                } else {
                    return (nil, nil, [], [])
                }
            }()
            
            // トップス表示
            if topsCategorize != nil && !affiliateTops.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("トップス")
                        .font(.system(size: 14))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(affiliateTops, id: \.self) { product in
                                AsyncImage(url: URL(string: product.image_url)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 120 * 0.8, height: 140 * 0.8)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    onProductTapped(product)
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // ボトムス表示
            if bottomsCategorize != nil && !affiliateBottoms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ボトムス")
                        .font(.system(size: 14))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(affiliateBottoms, id: \.self) { product in
                                AsyncImage(url: URL(string: product.image_url)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray.opacity(0.3)
                                }
                                .frame(width: 120 * 0.8, height: 140 * 0.8)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    onProductTapped(product)
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
    }
    
    private func ItemSearchButton(title: String, url: String) -> some View {
        Button(action: {
            if let urlObj = URL(string: url) {
                UIApplication.shared.open(urlObj, options: [:], completionHandler: nil)
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview("アフィリエイトデータありのRecommendCoordinates") {
    CoordinateReviewView(viewModel: .init(
        coordinateImage: UIImage(resource: .coordinate2),
        apiClient: MockFashionReviewClient(),
        recommendCoordinateClient: MockRecommendCoordinateClient(),
        analysisCoordinateClient: MockAnalysisCoordinateClient()
    ), path: .constant([]))
}

#Preview("アフィリエイトデータなし→AnalysisCoordinate表示") {
    CoordinateReviewView(viewModel: .init(
        coordinateImage: UIImage(resource: .coordinate2),
        apiClient: MockFashionReviewClient(),
        recommendCoordinateClient: MockEmptyAffiliateRecommendCoordinateClient(),
        analysisCoordinateClient: MockAnalysisCoordinateClient()
    ), path: .constant([]))
}

#Preview("両方とも空データ→エラー表示") {
    CoordinateReviewView(viewModel: .init(
        coordinateImage: UIImage(resource: .coordinate2),
        apiClient: MockFashionReviewClient(),
        recommendCoordinateClient: MockEmptyAffiliateRecommendCoordinateClient(),
        analysisCoordinateClient: MockEmptyAnalysisCoordinateClient()
    ), path: .constant([]))
}
