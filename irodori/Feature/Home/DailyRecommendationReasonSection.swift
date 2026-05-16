//
//  DailyRecommendationReasonSection.swift
//  irodori
//
//  「明日のコーデ」セクション・B 版（理由インライン）。
//  - 3×3 グリッド主役
//  - 未選択カードのタップ: 選択（枠線+理由パネル更新）
//  - 選択中カードのタップ or 右下拡大ボタン: onTap で詳細モーダルへ
//
//  キャプション版に戻したい場合は HomeView 側で
//  DailyRecommendationCaptionSection を呼び出してください。
//

import SwiftUI

struct DailyRecommendationReasonSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let prefectureName: String
    let onTap: (DailyRecommendationItem) -> Void
    let onLocationTap: () -> Void

    @State private var selectedIndex: Int = 0

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
                reasonPanel(items: r.recommendations)
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
        Button {
            handleTap(index: idx, item: item)
        } label: {
            ZStack(alignment: .topTrailing) {
                DailyGridImage(imageURL: item.image_url, isSelected: idx == selectedIndex)
                if idx == 0 {
                    DailyIchioshiBadge().padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if idx == selectedIndex {
                Button {
                    Haptic.impact(.soft)
                    onTap(item)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private func handleTap(index: Int, item: DailyRecommendationItem) {
        if index == selectedIndex {
            Haptic.impact(.soft)
            onTap(item)
        } else {
            Haptic.selection()
            withAnimation(.easeInOut(duration: 0.18)) { selectedIndex = index }
        }
    }

    // MARK: - Reason Panel

    private func reasonPanel(items: [DailyRecommendationItem]) -> some View {
        let safeIndex = min(max(selectedIndex, 0), max(items.count - 1, 0))
        let item = items[safeIndex]
        let bodyText: String = {
            if let r = item.reason, !r.isEmpty { return r }
            if !item.vibe.isEmpty { return item.vibe }
            return "明日のコンディションに合う一着です。"
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 13))
                Text("選んだ理由")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if !item.style.isEmpty { chip(item.style) }
                if !item.main_colors.isEmpty {
                    chip(item.main_colors.prefix(2).joined(separator: "・"))
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .clipShape(Capsule())
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 96)
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
