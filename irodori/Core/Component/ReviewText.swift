//
//  ReviewText.swift
//  irodori
//
//  Created by yuki.hamada on 2025/10/04.
//

import SwiftUI

struct ReviewText: View {
    @State var isShowFullReview: Bool
    let aiReviewComment: String
    let shortTextCriterion: Int = 50

    init(aiReviewComment: String) {
        self.aiReviewComment = aiReviewComment
        isShowFullReview = aiReviewComment.count < shortTextCriterion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AIのコーデコメント")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            if isShowFullReview {
                Text(.init(aiReviewComment))
                    .font(.system(size: 16, weight: .regular))
            } else {
                VStack(alignment: .leading) {
                    Text(.init("\(aiReviewComment.prefix(shortTextCriterion)) ..."))
                        .font(.system(size: 16, weight: .regular))
                    Button(action: {
                        isShowFullReview = true
                    }) {
                        Text("続きを見る")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

#Preview {
    ReviewText(aiReviewComment: "aiReviewComment")
}
