//
//  TagsView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/11/16.
//

import SwiftUI

struct TagsView: View {
    let tags: [String]
    let backgroundMaterial: Material
    let tagTextColor: Color
    let tagFont: Font
    let spacing: CGFloat
    let padding: EdgeInsets
    let borderColor: Color

    init(
        tags: [String],
        backgroundMaterial: Material = .ultraThinMaterial,
        tagTextColor: Color = .white,
        borderColor: Color = .clear,
        tagFont: Font = .system(size: 14, weight: .semibold),
        spacing: CGFloat = 8,
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    ) {
        self.tags = tags
        self.backgroundMaterial = backgroundMaterial
        self.tagTextColor = tagTextColor
        self.borderColor = borderColor
        self.tagFont = tagFont
        self.spacing = spacing
        self.padding = padding
    }
    
    var body: some View {
        FlowLayout(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(tags, id: \.self) { tag in
                TagView(
                    text: tag,
                    backgroundMaterial: backgroundMaterial,
                    textColor: tagTextColor,
                    font: tagFont,
                    padding: padding,
                    borderColor: borderColor
                )
            }
        }
    }
}

struct TagView: View {
    let text: String
    let backgroundMaterial: Material
    let textColor: Color
    let font: Font
    let padding: EdgeInsets
    let borderColor: Color

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(textColor)
            .padding(padding)
            .background(backgroundMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }
}

// MARK: - FlowLayout

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (subview, position) in zip(subviews, result.positions) {
            subview.place(at: CGPoint(x: position.x + bounds.minX, y: position.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        let maxWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // 改行
                currentX = 0
                currentY += lineHeight + verticalSpacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + horizontalSpacing
            maxX = max(maxX, currentX - horizontalSpacing)
        }
        
        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
