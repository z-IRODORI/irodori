//
//  SelectFirstTimePicView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/07.
//

import SwiftUI

struct SelectFirstTimePicView: View {
    private let okExampleImages: [ImageResource] = [.coordinate1, .coordinate2, .coordinate3, .coordinate4, .coordinate5]
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                // 撮影画像の例
                ExamplePics(title: "", textColor: .blue, images: okExampleImages)
                    .padding(.horizontal, -24)

                // コーデ分析を促す説明文
                VStack(spacing: 12) {
                    Text("最近のコーディネートを分析")
                        .font(.system(size: 24, weight: .bold))
                    Text(.init("1枚コーデを​送ると​ **あなただけの​相棒** が​作られます。​\n今​後​この​相棒が​あなたの​コーデ分析を​サポートします。​"))
                        .font(.system(size: 14, weight: .regular))
                }

                // 画像選択方法
                HStack(spacing: 12) {
                    CustomButton(title: "写真を選ぶ", textColor: .white, backgroundColor: .green, tappedAction: {})
                    CustomButton(title: "カメラを起動", textColor: .white, backgroundColor: .green, tappedAction: {})
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
                .frame(maxWidth: 150)
                .frame(height: 50)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 48))
        })
    }

    private func ExamplePics(title: String, textColor: Color, images: [ImageResource]) -> some View {
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
                    Spacer().frame(width: 12)
                    ForEach(images, id: \.self) { image in
                        Image(image)
                            .resizable()
                            .aspectRatio(3/4, contentMode: .fit)
                            .frame(width: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Spacer().frame(width: 24)
                }
            }
        }
        .padding(.vertical, 24)
    }
}

#Preview {
    SelectFirstTimePicView()
}
