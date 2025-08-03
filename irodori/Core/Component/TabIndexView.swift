//
//  TabIndexView.swift
//  irodori
//
//  Created by 濵田　悠樹 on 2025/08/03.
//

import SwiftUI

struct TabIndexView: View {
    let numberOfPages: Int
    let currentIndex: Int

    var dotSize = 10.0
    var spacing = 20.0
    var dotColor = Color.gray.opacity(0.3)
    var selectedDotColor = Color.black
    var borderColor = Color.gray

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<numberOfPages) { index in
                if index == currentIndex {
                    Circle()
                        .fill(selectedDotColor)
                        .frame(width: dotSize, height: dotSize)
                } else {
                    Circle()
                        .fill(dotColor)
                        .stroke(borderColor, lineWidth: 0.5)
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
    }
}

#Preview {
    TabIndexView(numberOfPages: 3, currentIndex: 0)
}
