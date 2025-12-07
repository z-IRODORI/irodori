//
//  SelectFirstTimePicView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/07.
//

import SwiftUI

struct SelectFirstTimePicView: View {
    private let okExampleImages: [ImageResource] = Array(repeating: [.coordinate1, .coordinate2, .coordinate3, .coordinate4, .coordinate5], count: 10).flatMap { $0 }
    @State private var scrollOffset: CGFloat = 0
    @State private var timer: Timer?
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                // 撮影画像の例
                ExamplePics(title: "", textColor: .blue, images: okExampleImages, scrollOffset: $scrollOffset)
                    .padding(.horizontal, -24)
                    .onAppear {
                        startAutoScroll()
                    }
                    .onDisappear {
                        stopAutoScroll()
                    }

                // コーデ分析を促す説明文
                VStack(spacing: 12) {
                    Text("最近のコーディネートを分析")
                        .font(.system(size: 24, weight: .bold))
                    Text(.init("1枚コーデを​送ると​ **あなただけの​相棒** が​作られます。​\n今​後​この​相棒が​あなたの​コーデ分析を​サポートします。​"))
                        .foregroundStyle(.gray)
                        .font(.system(size: 14, weight: .regular))
                }

                // 画像選択方法
                HStack(spacing: 12) {
                    CustomButton(title: "カメラを起動", textColor: .gray, backgroundColor: .white, tappedAction: {})
                    CustomButton(title: "写真を選ぶ", textColor: .white, backgroundColor: .green, tappedAction: {})
                }

                Divider().frame(maxWidth: .infinity).frame(height: 2)

                // 相棒についての説明
                WhatIsPartner()
                    .padding(.vertical, 24)
//                    .background(.yellow.opacity(0.1))
                    .padding(.horizontal, -24)

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .top) {
            Text("IRODORI")
                .font(.system(size: 24, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .foregroundStyle(.black)
                .background(.white)
        }
    }

    private func WhatIsPartner() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("相棒とは")
                .font(.system(size: 20, weight: .bold))
                .padding(.leading, 24)
            Text("あなたのコーデをよく知り、コーデ選びがより楽しくなるようサポートしてくれるパートナーです")
                .font(.system(size: 14, weight: .regular))
                .padding(.leading, 24)

            HStack(spacing: 0) {
                Spacer().frame(width: 24)
                Image(.whatispartner)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                Spacer().frame(width: 24)
            }
        }
    }

    private func CustomButton(title: String, textColor: Color, backgroundColor: Color, tappedAction: @escaping (() -> Void)) -> some View {
        Button(action: {
            tappedAction()
        }, label: {
            Text(.init(title))
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(textColor)
                .frame(maxWidth: 200)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(backgroundColor)
                        .shadow(color: .black, radius: 2, x: 0, y: 2)
                )
        })
    }
    
    private func ExamplePics(title: String, textColor: Color, images: [ImageResource], scrollOffset: Binding<CGFloat>) -> some View {
        VStack(spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .foregroundStyle(textColor)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(images, id: \.self) { image in
                        Image(image)
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(width: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .offset(x: -scrollOffset.wrappedValue)
            }
        }
        .padding(.vertical, 24)
    }

    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                scrollOffset += 1

                // 画像の幅と間隔を考慮してリセット位置を計算
                let imageWidth: CGFloat = 150
                let spacing: CGFloat = 6
                let totalWidth = CGFloat(okExampleImages.count) * (imageWidth + spacing)

                // スクロールが全ての画像を通過したらリセット
                if scrollOffset > totalWidth {
                    scrollOffset = 0
                }
            }
        }
    }

    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    SelectFirstTimePicView()
}
