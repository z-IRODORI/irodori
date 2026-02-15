//
//  SelectFirstTimePicView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/12/07.
//

import SwiftUI

struct FirstTakePhotoView: View {
    private let exampleImages1: [ImageResource] = Array(repeating: [.women1, .men1, .women2, .men2, .women3, .men3,.women4, .men4, .women5, .men5], count: 20).flatMap { $0 }
    private let exampleImages2: [ImageResource] = Array(repeating: [.women6, .men6, .women7, .men7, .women8, .men8, .women9, .men9, .women10, .men10], count: 20).flatMap { $0 }
    @Binding var path: [ViewType]
    @State private var scrollOffset: CGFloat = 0
    @State private var timer: Timer?
    @State var viewModel: FirstTakePhotoViewModel = .init(fashionReviewClient: FashionReviewClient())
    let okButtonTapped: (() -> ())

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 32) {
                Spacer().frame(height: 20)

                // 撮影画像の例
                VStack(spacing: 6) {
                    ExamplePics(title: "", textColor: .blue, images: exampleImages1, scrollOffset: $scrollOffset)
                    ExamplePics(title: "", textColor: .blue, images: exampleImages2, scrollOffset: $scrollOffset)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, -24)
                .onAppear {
                    startAutoScroll()
                }
                .onDisappear {
                    stopAutoScroll()
                }

                // コーデ分析を促す説明文
                VStack(spacing: 12) {
                    Text("さあ、IRODORIを始めましょう")
                        .font(.system(size: 24, weight: .bold))
                    Text(.init("1枚コーデを​送ると​ **あなただけの​相棒** が​作られます。​\n今​後​この​相棒が​あなたの​コーデ分析を​サポートします。​"))
                        .foregroundStyle(.gray)
                        .font(.system(size: 14, weight: .regular))
                }

                // 画像選択方法
                HStack(spacing: 12) {
                    CustomButton(title: "カメラを起動", textColor: .gray, backgroundColor: .white, tappedAction: {
                        viewModel.showCameraView = true
                    })
                    CustomButton(title: "写真を選ぶ", textColor: .white, backgroundColor: .black, tappedAction: {
                        viewModel.showPhotoPicker = true
                    })
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
        .fullScreenCover(isPresented: $viewModel.showCameraView) {
            CameraView(
                cameraViewModel: .init(),
                path: $path,
                onPhotoCaptured: { image in
                    viewModel.capturedImageFromCamera = image
                    viewModel.showCameraView = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPickerView(isPresented: $viewModel.showPhotoPicker) { image in
                // メソッド内で showConfirmationView が切り替わる
                // CapturedImageView を呼びだす
                viewModel.handleImageSelection(image)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showConfirmationView) {
            if let image = viewModel.selectedImage ?? viewModel.capturedImageFromCamera {
                CapturedImageView(
                    image: image,
                    viewModel: .init(inputUIImage: image),
                    isPresented: $viewModel.showConfirmationView,
                    okButtonTapped: {
                        okButtonTapped()
                        path.append(.coordinateReview(.init(image: image, fromFirstTakePhotoView: true)))
                    }
                )
            }
        }
        .onChange(of: viewModel.capturedImageFromCamera) { _, newImage in
            if newImage != nil {
                viewModel.showConfirmationView = true
            }
        }
        .onChange(of: viewModel.showConfirmationView) { _, isShowing in
            if !isShowing {
                // CapturedImageView が閉じられたら、キャプチャした画像をクリア
                viewModel.capturedImageFromCamera = nil
                viewModel.selectedImage = nil
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                .font(.system(size: 16, weight: .medium))
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
                            .scaledToFill()
//                            .aspectRatio(3/4, contentMode: .fill)
                            .frame(width: 130, height: 130 * (4/3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .offset(x: -scrollOffset.wrappedValue)
            }
        }
    }

    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                scrollOffset += 1

                // 画像の幅と間隔を考慮してリセット位置を計算
                let imageWidth: CGFloat = 150
                let spacing: CGFloat = 6
                let totalWidth = CGFloat(exampleImages1.count) * (imageWidth + spacing)

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
    FirstTakePhotoView(path: .constant([]), okButtonTapped: {})
}
