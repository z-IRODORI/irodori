//
//  QRFullScreenView.swift
//  irodori
//
//  ペアリング QR を全画面・最大輝度で表示する。カメラから 80cm〜1m 離しても読めるように、
//  画面いっぱいの大きさで出す。閉じると輝度を元に戻す。
//

import SwiftUI

struct QRFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var previousBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(geo.size.width, geo.size.height) - 32)
                    Text("カメラのレンズに向けて、80cm〜1m の距離で止めてください")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear {
            UIScreen.main.brightness = previousBrightness
        }
    }
}
