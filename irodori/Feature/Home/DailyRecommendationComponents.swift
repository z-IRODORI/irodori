//
//  DailyRecommendationComponents.swift
//  irodori
//
//  「明日のコーデ」セクションで共有する小さなビュー部品。
//  Section レイアウトの A/B/C を差し替えても見た目を揃えるため、
//  ヘッダ天気・partner_comment・イチオシ・3:4 縦長クロップ画像はここに集約する。
//

import SwiftUI
import Kingfisher

// MARK: - 天気アイコン判定

enum DailyWeatherDisplay {
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

// MARK: - 場所バッジ (天気の左に配置)

struct DailyLocationBadge: View {
    let prefectureName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.blue)
                Text(prefectureName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ミニ天気バッジ (見出し右に配置)

struct DailyMiniWeatherBadge: View {
    let weather: DailyRecommendationWeather

    var body: some View {
        let style = DailyWeatherDisplay.style(for: weather.condition)
        HStack(spacing: 6) {
            Image(systemName: style.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
                .foregroundStyle(style.tint)
            HStack(spacing: 2) {
                Text("\(weather.min_temp)")
                    .foregroundStyle(Color.blue.opacity(0.85))
                Text("/")
                    .foregroundStyle(.secondary)
                Text("\(weather.max_temp)")
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
}

// MARK: - partner_comment ボックス

struct DailyPartnerCommentBox: View {
    let text: String

    var body: some View {
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
}

// MARK: - イチオシバッジ
// IRODORI のデザイン言語に合わせた控えめな仕上げ:
//  - 白カプセル + 細いピンク縁 + ピンクテキスト (DailyMiniWeatherBadge と同系)
//  - 強い色面・グラデ・濃いシャドウは使わず、画像の主張を邪魔しない

struct DailyIchioshiBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .semibold))
            Text("イチオシ")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.2)
        }
        .foregroundStyle(Color.pink)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(.white)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.pink.opacity(0.35), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 3:4 縦長クロップ画像
// 画像タップで直接モーダルが開く構成のため、選択状態の枠線は廃止.

struct DailyGridImage: View {
    let imageURL: String

    var body: some View {
        Color.gray.opacity(0.15)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                KFImage(URL(string: imageURL))
                    .resizable()
                    .placeholder { Color.gray.opacity(0.15) }
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


// MARK: - 手持ちアイテムの丸アイコン

/// 推薦コーデに使われている手持ちアイテムを重ねた丸アイコンで表示する。
/// グリッドセル (小) と詳細画面 (大) で共用。
struct OwnedItemCircles: View {
    let items: [DailyOwnedItem]
    var size: CGFloat = 20
    var maxCount: Int = 3

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(items.prefix(maxCount).enumerated()), id: \.offset) { _, owned in
                KFImage(URL(string: owned.image_url))
                    .placeholder { Color.gray.opacity(0.25) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, x: 0, y: 0.5)
            }
        }
    }
}

/// 手持ち一致が無いコーデに付ける破線サークルバッジ。
/// 詳細画面の「足りないアイテム」(破線サークル) と同じ視覚言語で揃える。
struct NoOwnedItemBadge: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
            Circle()
                .strokeBorder(
                    Color.gray.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2])
                )
            Image(systemName: "tshirt")
                .font(.system(size: size * 0.45))
                .foregroundStyle(Color.gray.opacity(0.65))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
    }
}
