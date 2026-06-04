//
//  DailyRecommendationReasonSection.swift
//  irodori
//
//  「明日のコーデ」セクション。
//  - 見出し (タイトル + 場所バッジ + 天気バッジ)
//  - partner_comment ボックス
//  - 3×3 グリッド (画像タップで詳細モーダル / ハートでお気に入り)
//
//  ※ もともと "理由インライン版" として作成したが、選択&理由パネルは廃止し、
//    画像タップで直接モーダルが開くシンプルな構成に変更.
//    呼び出し側互換のためファイル名・型名はそのまま残している.
//

import SwiftUI

struct DailyRecommendationReasonSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let prefectureName: String
    let onTap: (DailyRecommendationItem) -> Void
    let onLocationTap: () -> Void

    @Environment(FavoritesStore.self) private var favoritesStore

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
            DailyLocationBadge(prefectureName: prefectureName, action: onLocationTap)
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
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                gridCell(index: idx, item: item)
            }
        }
    }

    private func gridCell(index idx: Int, item: DailyRecommendationItem) -> some View {
        let kind = item.kindEnum
        let isFav = favoritesStore.isFavoriteRespectingSession(
            kind: kind,
            targetId: item.pool_id,
            fallback: item.is_favorite
        )
        return ZStack(alignment: .topTrailing) {
            DailyGridImage(imageURL: item.image_url)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    Haptic.impact(.soft)
                    onTap(item)
                }
            if idx == 0 {
                DailyIchioshiBadge().padding(6)
            }
        }
        .overlay(alignment: .bottomLeading) {
            FavoriteToggleButton(isFavorite: isFav, size: 11, padding: 6) {
                Task {
                    await favoritesStore.setFavorite(
                        !isFav,
                        kind: kind,
                        targetId: item.pool_id,
                        imageURL: item.image_url
                    )
                }
            }
            .padding(6)
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 64)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<9, id: \.self) { _ in
                    Color.gray.opacity(0.15)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
    DailyRecommendationReasonSection(
        response: .mock(),
        isLoading: false,
        prefectureName: Prefecture.default.name,
        onTap: { _ in },
        onLocationTap: {}
    )
    .padding()
    .background(Color.gray.opacity(0.08))
}
