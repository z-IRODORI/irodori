//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    let coordinateImage: UIImage
    let coordinateReview: CoordinateReview

    private let criterionShortText = 150
    @State private var reviewText = ""
    @State private var isShowFullReview = false
    @State private var tappedRecommendItemURL = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 48) {
                Image(uiImage: coordinateImage)
                    .resizable()
                    .frame(width: 300/1.5, height: 400/1.5)   // WEARのコーデ画像サイズ をリサイズ
                    .scaledToFit()

                ReviewText()

                RecommendItems()
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .sheet(item: $tappedRecommendItem) { tappedRecommendItem in
//            WebView(url: URL(string: tappedRecommendItem.itemURL))
//        }
        .onChange(of: tappedRecommendItemURL) {
            let url = URL(string: tappedRecommendItemURL)!   // TODO: エラーハンドリング
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func ReviewText() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIからのコーデコメント")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if isShowFullReview {
                Text("\(coordinateReview.coordinate_review)")
                    .font(.system(size: 16, weight: .light))
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Text("\(coordinateReview.coordinate_review.prefix(criterionShortText)) ...")
                        .font(.system(size: 16, weight: .light))
                    Button(action: {
                        isShowFullReview = true
                    }) {
                        Text("続きを見る")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.blue)
                            .padding(.top, 26)
                    }
                }
            }
        }
    }

    private func RecommendItems() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("おすすめアイテム")
                .font(.system(size: 20, weight: .bold))

            RecommendItemText(coordinate_item: coordinateReview.coordinate_item01, recommend_item: coordinateReview.recommend_item01, recommend_item_url: coordinateReview.recommend_item01_url)

            RecommendItemText(coordinate_item: coordinateReview.coordinate_item02, recommend_item: coordinateReview.recommend_item02, recommend_item_url: coordinateReview.recommend_item02_url)

            RecommendItemText(coordinate_item: coordinateReview.coordinate_item03, recommend_item: coordinateReview.recommend_item03, recommend_item_url: coordinateReview.recommend_item03_url)
        }
    }

    private func RecommendItemText(coordinate_item: String, recommend_item: String, recommend_item_url: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(coordinate_item)")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: {
                tappedRecommendItemURL = recommend_item_url
            }, label: {
                Text("\(recommend_item)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            })
        }
    }

//    private func ItemCard(recommendItem: RecommendItem) -> some View {
//        VStack(alignment: .leading, spacing: 12) {
//            ZStack {
//                AsyncImage(url: URL(string: recommendItem.imageURL)!) { image in
//                    image.resizable()
//                } placeholder: {
//                    ProgressView()
//                }
//                .frame(width: 215/2, height: 258/2)   // ZOZOTOWN の商品画像サイズ をリサイズ
//                .scaledToFill()
//            }
//
//            Text("\(recommendItem.company)")
//                .font(.system(size: 14, weight: .regular))
//                .foregroundStyle(.black)
//                .padding(.top, -6)
//            Text("¥\(recommendItem.price)")
//                .font(.system(size: 16, weight: .bold))
//                .foregroundStyle(.black)
//
//        }
//    }
}

#Preview {
    CoordinateReviewView(
        coordinateImage: UIImage(resource: .coordinate1),
        coordinateReview: .mock()
    )
}
