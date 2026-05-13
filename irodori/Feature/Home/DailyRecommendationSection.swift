//
//  DailyRecommendationSection.swift
//  irodori
//
//  ホーム画面の「明日のコーデ」セクション。天気カード + ヒーローカード + 4×2 サブグリッドで合計9件表示。
//

import SwiftUI
import Kingfisher

struct DailyRecommendationSection: View {
    let response: DailyRecommendationResponse?
    let isLoading: Bool
    let onTap: (DailyRecommendationItem) -> Void

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader
            content
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Text("明日のコーデ")
                .font(.system(size: 20, weight: .bold))
            Spacer()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            skeleton
        } else if let r = response, !r.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                weatherCard(weather: r.weather, dateString: r.target_date)
                if let comment = r.partner_comment, !comment.isEmpty {
                    partnerComment(comment)
                }
                heroCard(item: r.recommendations[0])
                if r.recommendations.count > 1 {
                    altLabel
                    subGrid(items: Array(r.recommendations.dropFirst()))
                }
            }
        } else {
            emptyState
        }
    }

    // MARK: - Weather Card

    private func weatherCard(weather: DailyRecommendationWeather, dateString: String) -> some View {
        let style = WeatherDisplay.style(for: weather.condition)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(style.tint.opacity(0.14))
                    .frame(width: 56, height: 56)
                Image(systemName: style.iconName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 28))
                    .foregroundStyle(style.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherDisplay.formatDate(dateString))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(weather.condition)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    tempLabel(value: weather.min_temp, isMax: false)
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    tempLabel(value: weather.max_temp, isMax: true)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func tempLabel(value: Int, isMax: Bool) -> some View {
        let color = isMax ? Color.orange : Color.blue.opacity(0.85)
        let arrow = isMax ? "arrow.up" : "arrow.down"
        return HStack(spacing: 2) {
            Image(systemName: arrow)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)°")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
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

    // MARK: - Hero Card

    private func heroCard(item: DailyRecommendationItem) -> some View {
        Button(action: { onTap(item) }) {
            HStack(alignment: .top, spacing: 12) {
                KFImage(URL(string: item.image_url))
                    .resizable()
                    .placeholder {
                        Rectangle().fill(Color.gray.opacity(0.12))
                    }
                    .scaledToFill()
                    .frame(width: 130, height: 174)
                    .clipped()
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 8) {
                    pickBadge
                    Text(heroBody(item))
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    tagRow(item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func heroBody(_ item: DailyRecommendationItem) -> String {
        if let r = item.reason, !r.isEmpty { return r }
        if !item.vibe.isEmpty { return item.vibe }
        return "明日の気候と最近の傾向から選んだ一着です。"
    }

    private var pickBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text("今日のイチオシ")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [.orange, Color(red: 1.0, green: 0.45, blue: 0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func tagRow(_ item: DailyRecommendationItem) -> some View {
        let style = item.style.trimmingCharacters(in: .whitespaces)
        let colorText = item.main_colors.prefix(2).joined(separator: "・")
        HStack(spacing: 6) {
            if !style.isEmpty { tagChip(style) }
            if !colorText.isEmpty { tagChip(colorText) }
        }
    }

    private func tagChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Sub Grid

    private var altLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("ほかの提案")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func subGrid(items: [DailyRecommendationItem]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(items) { item in
                Button(action: { onTap(item) }) {
                    KFImage(URL(string: item.image_url))
                        .resizable()
                        .placeholder {
                            Rectangle().fill(Color.gray.opacity(0.15))
                        }
                        .scaledToFill()
                        .frame(height: 104)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Skeleton

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 84)
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.12))
                .frame(height: 198)
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 104)
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
        .frame(maxWidth: .infinity, minHeight: 130)
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

    static func formatDate(_ ymd: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let date = inFmt.date(from: ymd) else {
            return "明日"
        }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "ja_JP")
        outFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        outFmt.dateFormat = "明日 M月d日(E)"
        return outFmt.string(from: date)
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
