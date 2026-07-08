//
//  DailyRecommendationReasonSection.swift
//  irodori
//
//  「おすすめコーデ」セクション (旧: 明日のコーデ)。
//  9件のコーデを提案するため、タイトルは「おすすめコーデ」。
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
    /// 手持ちアイテム未登録ナッジのタップ (コーデ撮影シートを開く)
    var onRegisterItems: () -> Void = {}

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
            Text("おすすめコーデ")
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
                closetHintRow(items: r.recommendations)
            }
        } else {
            emptyState
        }
    }

    // 手持ちアイテム一致の補足行:
    //  - 丸アイコンが1つでもあれば意味の凡例 (初見で分かるように)
    //  - 1つも無ければ登録ナッジ (アイテムが少ないと表示されないため)
    @ViewBuilder
    private func closetHintRow(items: [DailyRecommendationItem]) -> some View {
        let hasAnyOwned = items.contains { !$0.owned_items.isEmpty }
        if hasAnyOwned {
            HStack(spacing: 6) {
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("画像右下: ◯=使える手持ちアイテム / 破線=手持ちと一致なし")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        } else {
            Button {
                Haptic.impact(.soft)
                onRegisterItems()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("アイテムを登録すると、手持ちで作れるコーデが分かります")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("コーデを撮影するとアイテムが自動で登録されます")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
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
        // 手持ちアイテムの一致表示: ◯ = 使える手持ちアイテム / 破線 = 一致なし。
        // pool コーデには必ずどちらかが付き、カードごとの再現可否が一目で分かる
        .overlay(alignment: .bottomTrailing) {
            if item.kindEnum == .pool {
                Group {
                    if !item.owned_items.isEmpty {
                        OwnedItemCircles(items: item.owned_items, size: 20)
                    } else {
                        NoOwnedItemBadge(size: 20)
                    }
                }
                .padding(6)
            }
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
