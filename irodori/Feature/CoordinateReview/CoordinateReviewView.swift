//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    let coordinateImage: UIImage
    let fashionReview: FashionReviewResponse

    private let shortTextCriterion = 50
    @State private var currentSchedule = ""   // YYYY/MM/DD
    @State private var reviewText = ""
    @State private var isShowFullReview = false
    @State private var tappedURL = ""
    @State private var isPresentedCameraView = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                Coordinate()
                RecentCoordinates()   // TODO: - 直近のコーデがない場合のUIを考える & 直近のコーデをVMで管理する
                ReviewText()
                    .padding(.horizontal, 24)
                CoordinateItems()
                    .padding(.horizontal, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    isPresentedCameraView = true
                }, label: {
                    Text("再撮影")
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
    }

    private func RecentCoordinates() -> some View {
        VStack(spacing: 12) {
            Text("直近のコーデ")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Spacer().frame(width: 12)

                    ForEach(fashionReview.recent_coordinates, id: \.self) { fashionReview in
                        RecentCoordinateCard(
                            imageURL: fashionReview.coodinate_image_path,
                            text: fashionReview.date
                        )
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
                    ForEach(fashionReview.items, id: \.self) { item in
                        CoordinateItemCard(
                            imageURL: item.item_image_path,
                            text: item.item_type, textColor: .black
                        )
                    }
                }
            }
        }
    }

    private func Coordinate() -> some View {
        ZStack {
            Image(uiImage: coordinateImage)
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
            Text("ロックな自由人、知的さと遊び心の絶妙ミックス")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxHeight: .infinity, alignment: .bottom)
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
                Text(.init(fashionReview.ai_comment))
                    .font(.system(size: 16, weight: .regular))
            } else {
                VStack {
                    Text("\(fashionReview.ai_comment.prefix(shortTextCriterion)) ...")
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
            isShowFullReview = fashionReview.ai_comment.count < shortTextCriterion
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

    private func CoordinateItemCard(imageURL: String, text: String, textColor: Color = .secondary) -> some View {
        VStack(spacing: 0) {
            AsyncImage(url: URL(string: imageURL)!) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
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
}

#Preview {
    CoordinateReviewView(
        coordinateImage: UIImage(resource: .coordinate2),
        fashionReview: .mock()
    )
}
