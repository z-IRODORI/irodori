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
    @Binding var isPresented: Bool
    @State private var isPresentedLoadingView = false

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
                            isPresentedLoadingView = true
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationDestination(isPresented: $isPresentedLoadingView) {
                LoadingView(coordinateImage: image)
            }
        }
    }
}

#Preview {
    CapturedImageView(image: UIImage(), isPresented: Binding.constant(true))
}
