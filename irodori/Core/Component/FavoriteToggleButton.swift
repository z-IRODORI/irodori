//
//  FavoriteToggleButton.swift
//  irodori
//
//  画像カード上に重ねるお気に入り切替ボタン (グリッド/詳細で共通利用).
//

import SwiftUI

struct FavoriteToggleButton: View {
    let isFavorite: Bool
    var size: CGFloat = 12
    var padding: CGFloat = 7
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.impact(.light)
            action()
        } label: {
            ZStack {
                // 未お気に入り: 白塗りのハート。白っぽい写真に埋もれないよう影を強めに
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 1.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.28), radius: 1.5, x: 0, y: 0.5)
                // お気に入り: ピンク塗り (オン/オフをフェードで切替)
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 1.5, weight: .regular))
                    .foregroundStyle(Color.pink)
                    .shadow(color: Color.pink.opacity(0.18), radius: 1.2, x: 0, y: 0.5)
                    .opacity(isFavorite ? 1 : 0)
            }
            .scaleEffect(isFavorite ? 1.0 : 0.96)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isFavorite)
            .padding(padding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 16) {
        FavoriteToggleButton(isFavorite: false) {}
        FavoriteToggleButton(isFavorite: true) {}
        FavoriteToggleButton(isFavorite: true, size: 16, padding: 10) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
