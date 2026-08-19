//
//  CoordinateItems.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

/// 「着用しているアイテム」の横スクロール一覧。
/// - v2 (useServerItems=true): サーバーが検出・生成したアイテム (背景透過の商品画像URL) を
///   全件表示し、タップでアイテム詳細シートを開ける。
/// - legacy: 従来どおりオンデバイス切り出しのトップス/ボトムス 2 枚を表示する。
struct CoordinateItems: View {
    let topsUIImage: UIImage?
    let bottomsUIImage: UIImage?
    var serverItems: [FashionReviewResponse.Item] = []
    var useServerItems: Bool = false
    var onTapItem: ((FashionReviewResponse.Item) -> Void)? = nil

    /// v2 で画像URLが入っているアイテムのみカード表示 (URL 空は保険で除外)
    private var displayableServerItems: [FashionReviewResponse.Item] {
        serverItems.filter { $0.item_image_path.hasPrefix("http") }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("着用しているアイテム")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if useServerItems && !displayableServerItems.isEmpty {
                        ForEach(displayableServerItems) { item in
                            Button {
                                onTapItem?(item)
                            } label: {
                                ServerItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        CoordinateItemCard(
                            uiImage: topsUIImage,
                            text: "トップス", textColor: .black
                        )

                        CoordinateItemCard(
                            uiImage: bottomsUIImage,
                            text: "ボトムス", textColor: .black
                        )
                    }
                }
            }
        }
    }

    /// v2: サーバー生成の背景透過アイテム画像カード (名前 + カラーの2行テキスト)
    private func ServerItemCard(item: FashionReviewResponse.Item) -> some View {
        VStack(spacing: 0) {
            CachedAsyncImage(url: URL(string: item.item_image_path)!) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 110, height: 110)
            .padding(12)

            VStack(spacing: 2) {
                Text(item.category ?? item.item_type)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(item.color ?? " ")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 8)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // legacy: コーデアイテム抽出をローカルで実行しているためuiImageを渡している
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
}
