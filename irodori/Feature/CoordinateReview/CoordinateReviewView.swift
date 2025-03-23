//
//  CoordinateReviewView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

struct CoordinateReviewView: View {
    let coordinateImage: UIImage
    let review = """
    黒のショルダーバッグがシンプルでコーデの引き締め役になっていて素敵ですね。
    トップスを軽くインしているので、ラフすぎず清潔感があります。\n程よくワイドなパンツを履いているので、リラックス感のある大人な印象を受けます。
    あなたのシルエットは「I」です。Iが似合うのは、縦長でスタイリッシュな印象を好む方や、シンプルで洗練された雰囲気を持った方です。
    また、あなたのコーデはカジュアルです。
    カジュアルが似合う方におすすめのコーデタイプは、シンプルで洗練された印象が特徴のノームコアです。
    画像の黒パンツに合うのは、白や淡いブルーのシャツです。理由としては、黒のパンツと明るい色味のシャツは相性がよく、シンプルながら爽やかで大人っぽい印象になるからです。
    """
    @State private var isShowFullReview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                Image(uiImage: coordinateImage)
                    .resizable()
                    .frame(width: 300/1.5, height: 400/1.5)   // WEARのコーデ画像サイズ をリサイズ
                    .scaledToFit()

                ReviewText()
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            isShowFullReview = review.count < 150
        }
    }

    private func ReviewText() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIからのコーデコメント")
                .font(.system(size: 24, weight: .bold))

            if isShowFullReview {
                Text("\(review)")
                    .font(.system(size: 16, weight: .light))
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Text("\(review.prefix(150)) ...")
                        .font(.system(size: 16, weight: .light))
                    Button(action: {
                        isShowFullReview = true
                    }) {
                        Text("続きを見る")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(.blue)
                            .offset(y: 10)
                    }
                }
            }
        }
    }

    private func RecommendItems() -> some View {
        HStack(spacing: 24) {

        }
    }

    private func ItemCard(cardUIImage: UIImage) -> some View {
        ZStack {
            Image(uiImage: cardUIImage)
        }
    }
}

#Preview {
    CoordinateReviewView(coordinateImage: UIImage(resource: .coordinate1))
}
