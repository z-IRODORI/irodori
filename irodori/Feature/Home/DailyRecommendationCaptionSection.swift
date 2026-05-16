//
//  DailyRecommendationCaptionSection.swift
//  irodori
//
//  「明日のコーデ」セクション・C 版（キャプション）。
//  - 3×3 グリッド主役
//  - 各カード下に vibe (フォールバック: style) を最大2行表示
//  - カードをタップ = 即 onTap で詳細モーダル
//
//  理由インライン版に戻したい場合は HomeView 側で
//  DailyRecommendationReasonSection を呼び出してください。
//

import SwiftUI

struct DailyRecommendationCaptionSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let onTap: (DailyRecommendationItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader
            content
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("明日のコーデ")
                .font(.system(size: 20, weight: .bold))
            Spacer()
            if let r = response {
                DailyMiniWeatherBadge(weather: r.weather)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeleton
        } else if let r = response, !r.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                if let comment = r.partner_comment, !comment.isEmpty {
                    DailyPartnerCommentBox(text: comment)
                }
                grid(items: r.recommendations)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Grid

    private func grid(items: [DailyRecommendationItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                Button {
                    Haptic.impact(.soft)
                    onTap(item)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            DailyGridImage(imageURL: item.image_url)
                            if idx == 0 {
                                DailyIchioshiBadge().padding(6)
                            }
                        }
                        Text(caption(for: item))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func caption(for item: DailyRecommendationItem) -> String {
        if !item.vibe.isEmpty { return item.vibe }
        if !item.style.isEmpty { return item.style }
        return ""
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 64)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<9, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        Color.gray.opacity(0.15)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 12)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .foregroundStyle(.gray)
            Text("推薦準備中…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}

#Preview {
    DailyRecommendationCaptionSection(
        response: .mock(),
        isLoading: false,
        onTap: { _ in }
    )
    .padding()
    .background(Color.gray.opacity(0.08))
}
