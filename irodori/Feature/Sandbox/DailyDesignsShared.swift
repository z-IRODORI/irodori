//
//  DailyDesignsShared.swift
//  irodori - Sandbox
//
//  「明日のコーデ」UI 検討の共通部品。
//  天気バー、partner_comment ボックス、イチオシバッジ、サンドボックス用モックを提供する。
//

import SwiftUI
import Kingfisher

// MARK: - 天気アイコン/日付ヘルパー

enum SandboxDaily {
    struct WeatherStyle {
        let icon: String
        let tint: Color
    }

    static func weatherStyle(for condition: String) -> WeatherStyle {
        let c = condition
        if c.contains("雷") { return .init(icon: "cloud.bolt.rain.fill", tint: .purple) }
        if c.contains("雪") { return .init(icon: "cloud.snow.fill", tint: .cyan) }
        if c.contains("雨") {
            if c.contains("晴") { return .init(icon: "cloud.sun.rain.fill", tint: .blue) }
            if c.contains("曇") { return .init(icon: "cloud.heavyrain.fill", tint: .blue) }
            return .init(icon: "cloud.rain.fill", tint: .blue)
        }
        if c.contains("曇") && c.contains("晴") {
            return .init(icon: "cloud.sun.fill", tint: .orange)
        }
        if c.contains("曇") { return .init(icon: "cloud.fill", tint: .gray) }
        if c.contains("晴") { return .init(icon: "sun.max.fill", tint: .orange) }
        return .init(icon: "cloud.sun.fill", tint: .gray)
    }

    static func formatDate(_ ymd: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        guard let date = inFmt.date(from: ymd) else { return "明日" }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "ja_JP")
        outFmt.timeZone = TimeZone(identifier: "Asia/Tokyo")
        outFmt.dateFormat = "明日 M月d日(E)"
        return outFmt.string(from: date)
    }

    // MARK: - サンドボックス用モック (production の .mock より差別化を強化)

    static func mockResponse() -> DailyRecommendationResponse {
        let styles  = ["カジュアル", "きれいめ", "モード", "ナチュラル", "ストリート",
                       "クラシック", "スポーティ", "フェミニン", "アメカジ"]
        let vibes   = ["春らしい爽やかさ", "落ち着いた清潔感", "シャープな大人感",
                       "やわらかい抜け感",  "アクティブな軽さ", "上品なまとまり",
                       "動きやすい1日",       "明るくやさしい",   "こなれた印象"]
        let reasons = [
            "気温18〜23℃に合う薄手の組合せ。先週よく着ていた白系トップスとも相性◎。",
            "曇りの予報なので、彩度を抑えたきれいめなトーンでまとめました。",
            "気温差があるため重ね着で調整しやすい構成。アウターは脱ぎ着しやすい軽量。",
            "最近選んでいたデニムベースに、新しいトップスの方向性を提案。",
            "クローゼットの白Tシャツを活かした春のベーシックコーデ。",
            "気温が高くなる午後を想定し、通気性のよい素材中心で構成。",
            "外出先で歩く時間が長くなりそうなら、動きやすいパンツが◎。",
            "色味の幅を広げる挑戦コーデ。普段選ばない暖色を1点加えました。",
            "シンプル過ぎず派手過ぎない、平日に使いやすいバランス。"
        ]
        let colors: [[String]] = [
            ["white","navy"], ["beige","black"], ["gray","khaki"],
            ["denim","white"], ["black","white"], ["brown","ivory"],
            ["olive","white"], ["pink","gray"], ["denim","brown"]
        ]
        let images = (1...9).map { "asset:coordinate-\($0)" }
        return .init(
            target_date: "2026-05-15",
            weather: .init(min_temp: 16, max_temp: 23, condition: "晴れ時々曇り", area_code: "130000"),
            partner_comment: "明日は過ごしやすい一日。最近よく選んでいるシンプル系をベースに、ライトに春らしさを足してみませんか？",
            recommendations: (0..<9).map { i in
                .init(
                    pool_id: "m_\(String(format: "%04d", i + 1))",
                    image_url: images[i % images.count],
                    reason: reasons[i],
                    main_colors: colors[i],
                    items: ["tops": "白Tシャツ", "bottoms": "ネイビーパンツ", "outer": nil, "accessory": nil],
                    vibe: vibes[i],
                    style: styles[i],
                    cleanliness: (i % 5) + 1
                )
            },
            mode: "cached"
        )
    }
}

// MARK: - コンパクト天気バー (1行)

struct SandboxCompactWeatherBar: View {
    let weather: DailyRecommendationWeather
    let dateString: String

    var body: some View {
        let style = SandboxDaily.weatherStyle(for: weather.condition)
        HStack(spacing: 8) {
            Image(systemName: style.icon)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 13))
                .foregroundStyle(style.tint)
            Text(SandboxDaily.formatDate(dateString))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(weather.condition)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
            HStack(spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                Text("\(weather.min_temp)°")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.blue.opacity(0.85))
            Text("/")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 8, weight: .bold))
                Text("\(weather.max_temp)°")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - partner_comment ボックス

struct SandboxPartnerComment: View {
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

// MARK: - ミニ天気バッジ (見出し右に納めるための超コンパクト版)

struct SandboxMiniWeather: View {
    let weather: DailyRecommendationWeather

    var body: some View {
        let style = SandboxDaily.weatherStyle(for: weather.condition)
        HStack(spacing: 6) {
            Image(systemName: style.icon)
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

// MARK: - 画像ラッパー (asset: プレフィックスでローカル/リモートを切替)

struct SandboxCoordImage: View {
    let source: String

    var body: some View {
        Group {
            if source.hasPrefix("asset:") {
                Image(String(source.dropFirst("asset:".count)))
                    .resizable()
            } else {
                KFImage(URL(string: source))
                    .placeholder { Rectangle().fill(Color.gray.opacity(0.15)) }
                    .resizable()
            }
        }
    }
}

// MARK: - イチオシバッジ

struct SandboxIchioshiBadge: View {
    var body: some View {
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
}

#Preview("共通: 天気バー + コメント") {
    let r = SandboxDaily.mockResponse()
    return VStack(spacing: 14) {
        SandboxCompactWeatherBar(weather: r.weather, dateString: r.target_date)
        if let c = r.partner_comment { SandboxPartnerComment(text: c) }
    }
    .padding(24)
    .background(Color.gray.opacity(0.08))
}
