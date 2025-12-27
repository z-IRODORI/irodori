//
//  ReccentCoordinates.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

struct RecentCoordinates: View {
    let recentCoordinates: [RecentCoordinate]

    var body: some View {
        VStack(spacing: 12) {
            Text("直近のコーデ")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            if recentCoordinates.isEmpty {
                Text("コーデが存在しません...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Spacer().frame(width: 12)
                        ForEach(recentCoordinates, id: \.self) { fashionReview in
                            RecentCoordinateCard(
                                imageURL: fashionReview.coodinate_image_path,
                                text: fashionReview.date
                            )
                        }
                        Spacer().frame(width: 12)
                    }
                }
            }
        }
    }

    private func RecentCoordinateCard(imageURL: String, text: String, _ textColor: Color = .secondary) -> some View {
        VStack(spacing: 0) {
            CachedAsyncImage(url: URL(string: imageURL)!) { phase in
                if let image = phase.image {
                    image.resizable()
                } else if phase.error != nil {
                    Color.red
                } else {
                    Color.gray.opacity(0.5)
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .frame(width: 110)

            Text("\(text)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
                .padding(.vertical, 10)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    RecentCoordinates(recentCoordinates: [])
}
