//
//  DailyRecommendationSection.swift
//  irodori
//
//  ホーム画面の「明日のコーデ」セクション。
//  - 見出し右にミニ天気バッジ
//  - partner_comment （全体方針）
//  - 3×3 グリッド（先頭に「イチオシ」バッジ）
//  - 選択中カードの直下に「選んだ理由」パネル
//  - 未選択カードのタップ: 選択（枠線+理由更新）
//  - 選択中カードのタップ or 右下拡大ボタン: onTap で詳細モーダルへ
//

import SwiftUI
import Kingfisher

struct DailyRecommendationSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let onTap: (DailyRecommendationItem) -> Void

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
            if let r = response {
                miniWeather(r.weather)
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
                    partnerComment(comment)
                }
                grid(items: r.recommendations)
                reasonPanel(items: r.recommendations)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Mini Weather

    private func miniWeather(_ w: DailyRecommendationWeather) -> some View {
        let style = WeatherDisplay.style(for: w.condition)
        return HStack(spacing: 6) {
            Image(systemName: style.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
                .foregroundStyle(style.tint)
            HStack(spacing: 2) {
                Text("\(w.min_temp)")
                    .foregroundStyle(Color.blue.opacity(0.85))
                Text("/")
                    .foregroundStyle(.secondary)
                Text("\(w.max_temp)")
                    .foregroundStyle(.orange)
                Text("°")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Partner Comment

    private func partnerComment(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 13))
                .foregroundStyle(Color.orange.opacity(0.75))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                KFImage(URL(string: item.image_url))
                    .resizable()
                    .placeholder { Rectangle().fill(Color.gray.opacity(0.15)) }
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(idx == selectedIndex ? Color.orange : Color.clear, lineWidth: 3)
                    )
                if idx == 0 {
                    ichioshiBadge.padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if idx == selectedIndex {
                Button { onTap(item) } label: {
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
            onTap(item)
        } else {
            withAnimation(.easeInOut(duration: 0.18)) { selectedIndex = index }
        }
    }

    private var ichioshiBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("イチオシ")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [.orange, Color(red: 1.0, green: 0.45, blue: 0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 150)
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

// MARK: - Weather Display Helpers

private enum WeatherDisplay {
    struct Style {
        let iconName: String
        let tint: Color
    }

    static func style(for condition: String) -> Style {
        let c = condition
        if c.contains("雷") {
            return .init(iconName: "cloud.bolt.rain.fill", tint: .purple)
        }
        if c.contains("雪") {
            return .init(iconName: "cloud.snow.fill", tint: .cyan)
        }
        if c.contains("雨") {
            if c.contains("晴") {
                return .init(iconName: "cloud.sun.rain.fill", tint: .blue)
            }
            if c.contains("曇") {
                return .init(iconName: "cloud.heavyrain.fill", tint: .blue)
            }
            return .init(iconName: "cloud.rain.fill", tint: .blue)
        }
        if c.contains("曇") && c.contains("晴") {
            return .init(iconName: "cloud.sun.fill", tint: .orange)
        }
        if c.contains("曇") {
            return .init(iconName: "cloud.fill", tint: .gray)
        }
        if c.contains("晴") {
            return .init(iconName: "sun.max.fill", tint: .orange)
        }
        return .init(iconName: "cloud.sun.fill", tint: .gray)
    }
}

#Preview {
    DailyRecommendationSection(
        response: .mock(),
        isLoading: false,
        onTap: { _ in }
    )
    .padding()
    .background(Color.gray.opacity(0.08))
}
