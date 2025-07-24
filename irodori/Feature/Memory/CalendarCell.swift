//
//  CalendarCell.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import SwiftUI
import Kingfisher

struct CalendarCell: View {
    var thumbnailImageURL: String?
    var height: CGFloat
    var dayOfMonth: Int

    var body: some View {
        Button {
            
        } label: {
            ZStack {
                // 全身画像
                if let thumbnailImageURL,
                   let imageURL = URL(string: thumbnailImageURL) {
                    KFImage.url(imageURL)
                        .loadDiskFileSynchronously()
                        .cacheMemoryOnly()
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .overlay { Color.black.opacity(0.3) }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // 日付
                Text(dayOfMonth.description)
                    .foregroundColor(thumbnailImageURL == nil ? .gray : .white)
                    .font(.headline)
                    .shadow(radius: thumbnailImageURL == nil ? 0 : 3)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.automatic)
    }

    private func PlaceholderView() -> some View {
        ProgressView()
            .background(.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
