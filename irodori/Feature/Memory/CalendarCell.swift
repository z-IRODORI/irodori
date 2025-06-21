//
//  CalendarCell.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/06/21.
//

import SwiftUI

struct CalendarCell: View {
    var beforeImageURL: String
    var afterImageURL: String
    var date: String
    var height: CGFloat
    var dayOfMonth: Int

    @State var showSheet:Bool = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            if let imageURL = URL(string: afterImageURL) {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 4)
                        )
                } placeholder: {
                    ProgressView()
                        .background(.gray.opacity(0.4))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 4)
                        )
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray)
                        .frame(height: height)
                    Text(dayOfMonth.description)
                        .foregroundColor(.white)
                        .font(.headline)
                        .shadow(radius: 3)
                }
            }
        }
        .buttonStyle(.automatic)
        .sheet(isPresented: $showSheet) {
            //
        }
    }
}
