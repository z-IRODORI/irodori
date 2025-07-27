//
//  CapturedImageView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/03/22.
//

import SwiftUI

// キャプチャした画像表示View
struct CapturedImageView: View {
    let image: UIImage
    let viewModel: CapturedImageViewModel
    @Binding var isPresented: Bool
    let okButtonTapped: () -> Void
    init(image: UIImage, viewModel: CapturedImageViewModel, isPresented: Binding<Bool>, okButtonTapped: @escaping () -> Void) {
        self.image = image
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.okButtonTapped = okButtonTapped
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack {
                        Button("破棄") {
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding()

                        Spacer()

    //                    Button("保存") {
    //                        // 画像を保存
    //                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    //                        isPresented = false
    //                    }
    //                    .foregroundColor(.white)
    //                    .padding()

                        Button("送信") {
                            okButtonTapped()
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }

                if viewModel.isLoading {
                    Color.black.opacity(0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    ProgressView()
                }
            }
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

#Preview {
    CapturedImageView(
        image: UIImage(),
        viewModel: .init(inputUIImage: .init()),
        isPresented: Binding.constant(true),
        okButtonTapped: {}
    )
}
