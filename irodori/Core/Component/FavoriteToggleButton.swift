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
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .padding(padding)
                .background {
                    if isFavorite {
                        LinearGradient(
                            colors: [.orange, Color(red: 1.0, green: 0.45, blue: 0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.black.opacity(0.45)
                    }
                }
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
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
