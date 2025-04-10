//
//  SelectTagView.swift
//  irodori
//
//  Created by yuki.hamada on 2025/04/09.
//

import SwiftUI

struct SelectTagView: View {
    @State private var selectedTag: OutingPurposeType = .business

    private let viewModel: SelectTagViewModel = .init()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日は何をしますか？")
                .font(.system(size: 24, weight: .bold))

            TagButtons()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)

    }

    private func TagButtons() -> some View {
        var width: CGFloat = .zero
        var height: CGFloat = .zero

        return ZStack(alignment: .topLeading) {
            ForEach(viewModel.tags, id: \.self) { tag in
                Button(action: {
                    selectedTag = tag
                }, label: {
                    Tag(tag: tag, selectedTag: selectedTag)
                })
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .alignmentGuide(.leading, computeValue: { d in
                    if abs(width - d.width) > 330.0 {
                        width = 0
                        height -= d.height
                    }
                    let saveWidth = width
                    if tag == viewModel.tags.last {
                      width = 0
                    } else {
                      width -= d.width
                    }
                    return saveWidth
                })
                .alignmentGuide(.top, computeValue: { _ in
                    let saveHeight = height
                    if tag == viewModel.tags.last {
                      height = 0
                    }
                    return saveHeight
                })
            }
        }
    }

    private func Tag(tag: OutingPurposeType, selectedTag: OutingPurposeType) -> some View {
        let cornerRadius = 20.0

        return Text(tag.name)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(selectedTag == tag ? .black.opacity(0.8) : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedTag == tag ? .blue.opacity(0.3) : .white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        selectedTag == tag ? .blue : .gray,
                        lineWidth: selectedTag == tag ? 4 : 1
                    )
            )
            .cornerRadius(cornerRadius)
    }
}

#Preview {
    SelectTagView()
}
