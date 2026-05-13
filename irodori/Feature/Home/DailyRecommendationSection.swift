//
//  DailyRecommendationSection.swift
//  irodori
//
//  ホーム画面の「明日のコーデ」セクション。3x3 グリッドで9件表示。
//

import SwiftUI
import Kingfisher

struct DailyRecommendationSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let onTap: (DailyRecommendationItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .foregroundColor(.orange)
            Text("明日のコーデ")
                .font(.headline)
            if let r = response {
                Text("\(r.weather.min_temp)〜\(r.weather.max_temp)℃ / \(r.weather.condition)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeleton
        } else if let r = response, !r.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                if let comment = r.partner_comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(8)
                }
                grid(items: r.recommendations)
            }
        } else {
            emptyState
        }
    }

    private func grid(items: [DailyRecommendationItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                Button(action: { onTap(item) }) {
                    KFImage(URL(string: item.image_url))
                        .resizable()
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.15))
                        }
                        .scaledToFill()
                        .frame(width: nil, height: 130)
                        .clipped()
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var skeleton: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<9, id: \.self) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 130)
                    .cornerRadius(8)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .foregroundColor(.gray)
            Text("推薦準備中…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }
}

#Preview {
    DailyRecommendationSection(
        response: .mock(),
        isLoading: false,
        onTap: { _ in }
    )
    .padding()
}
