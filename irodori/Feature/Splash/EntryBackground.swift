//
//  EntryBackground.swift
//  irodori
//
//  起動直後の画面 (利用規約・ログイン・アカウント確認中) で共通に使う背景。
//  3人の写真 (splash01) を同じ切り抜き方で敷き、ロゴとコピーを同じ位置に置く。
//  (以前は利用規約の画面だけ写真を引き伸ばしていて、画面ごとに見た目が変わっていた)
//

import SwiftUI

struct EntryBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image(.splash01)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .overlay {
            VStack(spacing: 12) {
                Image(.logoWhite)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 50)
                Text("今日のコーデに納得を、人生にIRODORIを")
                    .foregroundStyle(.white)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }
}

#Preview {
    EntryBackground()
}
