//
//  SpeechBubbleView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/13.
//

import SwiftUI

struct SpeechBubble: Shape {
    private let radius: CGFloat
    private let tailSize: CGFloat

    init(radius: CGFloat = 10) {
        self.radius = radius
        tailSize = 20
    }

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height / 2))
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - rect.height / 2 - tailSize),
                control1: CGPoint(x: rect.minX - tailSize, y: rect.maxY - rect.height / 2),
                control2: CGPoint(x: rect.minX, y: rect.maxY - rect.height / 2 - tailSize / 2)
            )
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: 270),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }
    }
}

struct SpeechBubbleView: View {
    let text: String
    let textSize: CGFloat = 16
    let maxHeight: CGFloat = 80

    var body: some View {
        SpeechBubble()
            .stroke(Color.gray, lineWidth: 2)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .overlay {
                Text(text)
                    .font(.system(size: textSize))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
                    .padding(.leading, 6)   // 吹き出しの尻尾部分の余白
            }
            .background(
                SpeechBubble()
                    .fill(Color.white) // 白背景
                    .shadow(color: .gray.opacity(0.3), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal, 12)   // background の後に設定することで背景の横幅を調整している
    }
}
