//
//  RecommendCoordinateView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/06.
//

import SwiftUI

struct RecommendCoordinateView: View {
    @State var viewModel: RecommendCoordinateViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                switch viewModel.recommendCoordinatesState {
                case .loading, .initial:
                    VStack(alignment: .center) {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let recommendCoordinates):
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            if let recommendReasons = recommendCoordinates.recommend_reasons {
                                Text(recommendReasons)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // 左端に24pxの空白を空けたいのでSpacerで表現
                                    // スクロールすると空白は消えてほしいのでpaddingではなくSpacer
                                    Spacer().frame(width: 24)
                                    ForEach(recommendCoordinates.coordinates, id: \.self) { recommendCoordinate in
                                        CachedAsyncImage(url: .init(string: recommendCoordinate.image_url)) { phase in
                                            if let image = phase.image {
                                                image.resizable()
                                                    .aspectRatio(contentMode: .fit)   // 角丸を適応させるため
                                                    .onTapGesture {
                                                        viewModel.setSelectedRecommendCoordinate(coordinate: recommendCoordinate)
                                                    }
                                            } else if phase.error != nil {
                                                Color.red
                                            } else {
                                                Color.gray.opacity(0.5)
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .frame(width: 120, height: 120 * 1.38)   // 1:1.38

                                    }
                                    Spacer().frame(width: 24)
                                }
                            }

                            AffiliateItems(title: "トップス", affiliateProducts: viewModel.selectedRecommendCoordinate.affiliate_tops)
                            AffiliateItems(title: "ボトムス", affiliateProducts: viewModel.selectedRecommendCoordinate.affiliate_bottoms)
                        }
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
            .background(.gray.opacity(0.08))
            .navigationBarTitle("おすすめのコーデ/アイテム", displayMode: .inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                DismissButton()
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.isShowingWebView) {
            WebViewContainer(url: URL(string: viewModel.webURLString)!)
        }
        .interactiveDismissDisabled(true)
    }

    private func DismissButton() -> some View {
            // Close
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            }
    }

    /// アフェリエイトの商品を横並びに表示する
    ///
    /// 商品の表示サイズは width: 100, height: 100
    /// 商品をタップすると viewModel.setWebViewURLString(url: String) を呼び出し、WebViewを表示する
    private func AffiliateItems(title: String?, affiliateProducts: [AffiliateProduct]) -> some View {
        VStack(spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
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
                                    .aspectRatio(contentMode: .fit)// 角丸を適応させるため
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
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 120, height: 180)
                    }
                    Spacer().frame(width: 24)
                }
            }
        }
    }
}

#Preview {
    RecommendCoordinateView(
        viewModel: .init(recommendCoordinateClient: MockRecommendCoordinateClient())
    )
}
