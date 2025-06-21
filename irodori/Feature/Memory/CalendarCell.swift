//
//  CalendarCell.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import SwiftUI
import Kingfisher

struct CalendarCell: View {
    var thumbnailImageURL: String
    var height: CGFloat
    var dayOfMonth: Int

    @State var showSheet:Bool = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            ZStack {
                // 全身画像
                if let imageURL = URL(string: thumbnailImageURL) {
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
                    .foregroundColor(.white)
                    .font(.headline)
                    .shadow(radius: 3)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .buttonStyle(.automatic)
        .sheet(isPresented: $showSheet) {
            //
        }
    }

    private func PlaceholderView() -> some View {
        ProgressView()
            .background(.gray.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
