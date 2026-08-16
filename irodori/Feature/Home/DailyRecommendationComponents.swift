//
//  DailyRecommendationComponents.swift
//  irodori
//
//  「明日のコーデ」セクションで共有する小さなビュー部品。
//  Section レイアウトの A/B/C を差し替えても見た目を揃えるため、
//  ヘッダ天気・partner_comment・イチオシ・3:4 縦長クロップ画像はここに集約する。
//

import SwiftUI
import UIKit
import Kingfisher

// MARK: - 天気アイコン判定
//
// ウェザーニュースの天気アイコン体系 (https://weathernews.jp/s/topics/img/wxicon/) に準拠する:
//  - 複合天気は「前半 (先に現れる天気) がベース系統」を決める
//    (100番台=晴れ / 200=くもり / 300=雨 / 400=雪。例: 晴れのち雨 = 晴れベースの雨複合 112)
//  - 「時々 / 一時 / のち」の副天気は複合グリフとベース色で表現する
//    (晴れ時々くもり=オレンジの cloud.sun / くもり時々晴れ=グレーの cloud.sun で向きを区別)
//  - 専用コード相当 (霧200・みぞれ430・小雨650・大雨/嵐850・大雪/吹雪950・猛暑550) は
//    複合解析より先に専用アイコンへマップする

enum DailyWeatherDisplay {
    struct Style {
        /// SF Symbols 名 (ウェザーニュースアイコンが使えない場合のフォールバック表示用)
        let iconName: String
        let tint: Color
        /// ウェザーニュースの天気アイコンコード (100/200/300/400 番台 + 特殊コード)。
        /// nil は未知の文言 (SF Symbols フォールバックのみ)
        let wxiconCode: Int?
        /// ウェザーニュースの文言 (「晴れのち雨」等)。info ポップアップの見出しに使う
        let label: String?
        /// ウェザーニュースの各アイコンの説明文言。info ポップアップの詳細に使う
        /// (見出しの言い換えではなく「どういう空になるか」の説明)
        let description: String?

        /// Assets.xcassets/wxicon/ のアセット名 (例: wx112)
        var wxAssetName: String? { wxiconCode.map { "wx\($0)" } }
    }

    /// 天気の系統 (ウェザーニュースの 100/200/300/400 番台に対応)
    private enum Family {
        case sunny, cloudy, rain, snow, fog
    }

    /// ウェザーニュースのアイコンコード → 文言 (https://weathernews.jp/s/topics/img/wxicon/)
    private static let wxLabels: [Int: String] = [
        100: "晴れ", 101: "晴れ時々くもり", 102: "晴れ一時雨", 104: "晴れ一時雪",
        110: "晴れのちくもり", 112: "晴れのち雨", 115: "晴れのち雪",
        200: "くもり", 201: "くもり時々晴れ", 202: "くもり時々雨", 204: "くもり時々雪",
        210: "くもりのち晴れ", 212: "くもりのち雨", 215: "くもりのち雪",
        300: "雨", 301: "雨時々晴れ", 302: "雨時々止む", 303: "雨時々雪",
        311: "雨のち晴れ", 313: "雨のちくもり", 314: "雨のち雪",
        400: "雪", 401: "雪時々晴れ", 402: "雪時々止む", 403: "雪時々雨",
        411: "雪のち晴れ", 413: "雪のちくもり", 414: "雪のち雨",
        430: "みぞれ", 550: "猛暑", 650: "小雨", 850: "大雨・嵐", 950: "大雪・吹雪",
    ]

    /// ウェザーニュースのアイコンコード → 説明文言 (https://weathernews.jp/s/topics/img/wxicon/ の原文)。
    /// 215 のみページに記載が無いため、212 と同型の雪版として補完している。
    private static let wxDescriptions: [Int: String] = [
        100: "雲が少なく、昼間なら青空が広がり、夜なら星空が見られます。また、少し白っぽい空でも日差しがタップリあります。",
        101: "だいたい晴れますが、時々、雲が日差しを遮ります。",
        102: "だいたい晴れますが、数時間だけ雨が降ります。",
        104: "だいたい晴れますが、数時間だけ雪が降ります。",
        110: "晴れていても、だんだん雲が多くなって、時々、日差しを遮ります。",
        112: "晴れていても、だんだん曇り空に変わり、数時間だけ雨が降ります。",
        115: "晴れていても、だんだん曇り空に変わり、数時間だけ雪が降ります。",
        200: "空は雲に覆われて、昼間は青空が、夜は星がほとんど見ることができません。",
        201: "雲は多いですが、時々青空が見えたり、日差しが差したりします。",
        202: "曇り空で、数時間だけ雨が降ります。",
        204: "曇り空で、数時間だけ雪が降ります。",
        210: "曇り空ですが、だんだん雲が少なくなって、時々青空が見えたり、日が差したりすることがあります。",
        212: "曇り空がしばらく続きますが、だんだん雨雲に変わり、数時間だけ雨が降ります。",
        215: "曇り空がしばらく続きますが、だんだん雪雲に変わり、数時間だけ雪が降ります。",
        300: "雨が降り続いたり、一旦やんでもすぐに雨が降り出します。雷が鳴ることもあります。",
        301: "降り続いた雨が一旦やんで、数時間だけ晴れたり、日が差したりします。",
        302: "雨が降っても、時々やんだりします。",
        303: "雨に雪が混じったり、時々雪に変わったりします。",
        311: "降っていた雨が急にやんで、時々青空が見えたり、日が差したりすることがあります。",
        313: "降っていた雨がやんできますが、雨がやんだ後も空は雲に覆われます。",
        314: "降っていた雨がやんだ後、雪が降ったりやんだりします。",
        400: "雪が降り続いたり、一旦やんでもすぐに雪が降り出します。雷が鳴ることもあります。",
        401: "降り続いた雪が一旦やんで、数時間だけ晴れたり、日が差したりします。",
        402: "雪が降っても、時々やんだりします。",
        403: "雪に雨が混じったり、時々雨に変わったりします。",
        411: "降っていた雪が急にやんで、時々青空が見えたり、日が差したりすることがあります。",
        413: "降っていた雪がやんできますが、雪がやんだ後も空は雲に覆われます。",
        414: "降っていた雪が、だんだん雨に変わります。",
        430: "雪や雨が降ったり、みぞれが降ります。雷が鳴ることもあります。",
        550: "気温が体温くらいか、それ以上に上がり、熱中症の危険性が高まるほどの、厳しい暑さになります。",
        650: "傘が必要ない程度の弱い雨がポツポツと降ります。",
        850: "土砂降りの激しい雨が続いたり、雨風が強まって、大荒れの天気になります。",
        950: "雪がドカドカと強く降って大雪になったり、視界が悪くなるほどの激しい吹雪になります。",
    ]

    private static func make(
        _ code: Int?, _ icon: String, _ tint: Color, labelOverride: String? = nil
    ) -> Style {
        Style(
            iconName: icon, tint: tint, wxiconCode: code,
            label: labelOverride ?? code.flatMap { wxLabels[$0] },
            description: code.flatMap { wxDescriptions[$0] }
        )
    }

    static func style(for condition: String) -> Style {
        let c = condition

        // --- 専用アイコン (特殊コード群)。複合解析より優先する ---
        if c.contains("猛暑") || c.contains("酷暑") {
            return make(550, "thermometer.sun.fill", .red)
        }
        if c.contains("台風") || c.contains("嵐") {
            return make(850, "tropicalstorm", .indigo)
        }
        if c.contains("雷") {
            // WN のアイコン一覧に雷単独は無く 850 (大雨・嵐) へ集約。文言は雷雨と明示する
            return make(850, "cloud.bolt.rain.fill", .purple, labelOverride: "雷雨")
        }
        if c.contains("みぞれ") {
            return make(430, "cloud.sleet.fill", .cyan)
        }
        if c.contains("吹雪") || c.contains("暴風雪") {
            return make(950, "wind.snow", .cyan)
        }
        if c.contains("大雪") {
            return make(950, "snowflake", .cyan)
        }
        if c.contains("大雨") || c.contains("豪雨") || c.contains("暴風雨") {
            return make(850, "cloud.heavyrain.fill", .blue)
        }
        if c.contains("小雨") || c.contains("霧雨") {
            return make(650, "cloud.drizzle.fill", .blue)
        }

        // 「のち」(遷移) か「時々/一時」(断続) かでコードが分かれる。
        // 気象庁文の「後」も遷移として扱うが、「午後」の「後」は誤検出しない
        let transition = c.contains("のち")
            || c.replacingOccurrences(of: "午後", with: "").contains("後")

        // --- 前半ベース + 副天気の複合マトリクス ---
        let (primary, secondary) = primaryAndSecondary(in: c)
        switch (primary, secondary) {
        case (.sunny, nil):      return make(100, "sun.max.fill", .orange)
        case (.sunny, .cloudy):  return make(transition ? 110 : 101, "cloud.sun.fill", .orange)
        case (.sunny, .rain):    return make(transition ? 112 : 102, "cloud.sun.rain.fill", .blue)
        case (.sunny, .snow):    return make(transition ? 115 : 104, "sun.snow", .cyan)

        case (.cloudy, nil):     return make(200, "cloud.fill", .gray)
        case (.cloudy, .sunny):  return make(transition ? 210 : 201, "cloud.sun.fill", .gray)
        case (.cloudy, .rain):   return make(transition ? 212 : 202, "cloud.rain.fill", .blue)
        case (.cloudy, .snow):   return make(transition ? 215 : 204, "cloud.snow.fill", .cyan)

        case (.rain, nil):       return make(c.contains("止む") ? 302 : 300, "cloud.rain.fill", .blue)
        case (.rain, .sunny):    return make(transition ? 311 : 301, "cloud.sun.rain.fill", .blue)
        case (.rain, .cloudy):   return make(transition ? 313 : 302, "cloud.rain.fill", .blue)
        case (.rain, .snow):     return make(transition ? 314 : 303, "cloud.sleet.fill", .cyan)

        case (.snow, nil):       return make(c.contains("止む") ? 402 : 400, "cloud.snow.fill", .cyan)
        case (.snow, .sunny):    return make(transition ? 411 : 401, "sun.snow", .cyan)
        case (.snow, .cloudy):   return make(transition ? 413 : 402, "cloud.snow.fill", .cyan)
        case (.snow, .rain):     return make(transition ? 414 : 403, "cloud.sleet.fill", .cyan)

        // 霧は単独ならくもり系の共有アイコン (200)、複合の副側はくもり扱い
        case (.fog, _):          return make(200, "cloud.fog.fill", .gray, labelOverride: "霧")
        case (_, .fog):          return style(for: c.replacingOccurrences(of: "霧", with: "くもり"))

        default:                 return make(nil, "cloud.sun.fill", .gray)
        }
    }

    /// 条件文の「先に現れる系統」と「次に現れる別系統」を返す。
    /// ウェザーニュースの複合アイコンは前半がベースになるため、出現位置で判定する
    /// (例: 晴れのち雨 → (.sunny, .rain) / 雨のち晴れ → (.rain, .sunny))。
    private static func primaryAndSecondary(in condition: String) -> (Family?, Family?) {
        let keywords: [(String, Family)] = [
            ("晴", .sunny), ("曇", .cloudy), ("くもり", .cloudy),
            ("霧", .fog), ("雨", .rain), ("雪", .snow),
        ]
        var hits: [(offset: Int, family: Family)] = []
        for (keyword, family) in keywords {
            guard let range = condition.range(of: keyword) else { continue }
            let offset = condition.distance(from: condition.startIndex, to: range.lowerBound)
            // 同一系統 (曇/くもり) は最初の出現だけ採用する
            if let index = hits.firstIndex(where: { $0.family == family }) {
                if offset < hits[index].offset { hits[index].offset = offset }
            } else {
                hits.append((offset, family))
            }
        }
        let ordered = hits.sorted { $0.offset < $1.offset }.map(\.family)
        return (ordered.first, ordered.count > 1 ? ordered[1] : nil)
    }
}

extension DailyWeatherDisplay {
    /// 天気そのものを表す語 (完全一致で拾う。「雷を伴い」等の修飾句は落とす)。
    /// ウェザーニュースのアイコン一覧にある特殊系 (霧・小雨・猛暑・吹雪・止む 等) も
    /// 説明文から欠落しないよう網羅する
    private static let weatherTerms: Set<String> = [
        "晴れ", "晴", "くもり", "曇り", "曇", "霧",
        "雨", "大雨", "小雨", "霧雨", "雷雨", "暴風雨",
        "雪", "大雪", "吹雪", "暴風雪", "みぞれ",
        "雷", "猛暑", "止む",
    ]
    private static let weatherConnectives: Set<String> = ["後", "のち", "時々", "一時"]

    /// 気象庁の condition は「晴れ 後 くもり 夜 雨 所により 昼過ぎ まで…」のような長文が
    /// 入るため、UIに収まるよう主要語だけに短縮する (サーバ側 compact_weather_condition と同仕様)
    static func compactCondition(_ condition: String) -> String {
        let tokens = condition
            .replacingOccurrences(of: "　", with: " ")
            .split(separator: " ")
            .map(String.init)

        var kept: [String] = []
        for token in tokens where kept.count < 4 {
            if weatherConnectives.contains(token) {
                if let last = kept.last, !weatherConnectives.contains(last) {
                    kept.append(token)
                }
            } else if weatherTerms.contains(token) {
                kept.append(token)
            }
        }
        while let last = kept.last, weatherConnectives.contains(last) {
            kept.removeLast()
        }
        if kept.isEmpty {
            let trimmed = condition.replacingOccurrences(of: "　", with: "")
            return trimmed.count > 8 ? String(trimmed.prefix(8)) + "…" : trimmed
        }
        return kept.joined()
    }
}

// MARK: - 系統 (genre) の日本語表示

/// API の `style` は母集団CSV由来の英語値 (casual / korean / office_casual / sporty など) が
/// そのまま返るため、表示用に日本語へ直す。未知の値は原文のまま出す
enum GenreDisplay {
    private static let japanese: [String: String] = [
        "casual": "カジュアル", "korean": "韓国っぽい", "office_casual": "オフィスカジュアル",
        "sporty": "スポーティ", "vintage": "ヴィンテージ", "minimal": "ミニマル",
        "mode": "モード", "street": "ストリート", "natural": "ナチュラル",
        "kirei": "きれいめ", "kireime": "きれいめ", "feminine": "フェミニン",
        "girly": "ガーリー", "american": "アメカジ", "amekaji": "アメカジ",
    ]

    static func ja(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        return japanese[raw] ?? raw
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

// MARK: - ウェザーニュース天気アイコン

/// ウェザーニュースの天気アイコン画像 (Assets.xcassets/wxicon/wx{code})。
/// 未知の文言などアセットが無い場合は SF Symbols 表示にフォールバックする。
struct WxWeatherIcon: View {
    let condition: String
    var size: CGFloat = 18

    var body: some View {
        let style = DailyWeatherDisplay.style(for: condition)
        if let asset = style.wxAssetName, UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: style.iconName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: size * 0.85))
                .foregroundStyle(style.tint)
        }
    }
}

// MARK: - 天気の説明ポップアップ (info ボタンから表示)

struct WeatherInfoPopover: View {
    let weather: DailyRecommendationWeather

    var body: some View {
        let style = DailyWeatherDisplay.style(for: weather.condition)
        VStack(spacing: 10) {
            WxWeatherIcon(condition: weather.condition, size: 44)
            // 見出しはウェザーニュースのアイコン一覧と同じ文言
            Text(style.label ?? weather.condition)
                .font(.system(size: 15, weight: .bold))
            // 詳細はウェザーニュースの各アイコンの説明文言 (見出しの言い換えではなく
            // 「どういう空になるか」の説明)。未知の文言だけ元の予報文を出す
            Text(style.description ?? weather.condition)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text("最低 \(weather.min_temp)°")
                    .foregroundStyle(Color.blue.opacity(0.85))
                Text("/")
                    .foregroundStyle(.secondary)
                Text("最高 \(weather.max_temp)°")
                    .foregroundStyle(.orange)
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(16)
        .frame(width: 260)
        .presentationCompactAdaptation(.popover)
    }
}

// MARK: - ミニ天気バッジ (見出し右に配置)

struct DailyMiniWeatherBadge: View {
    let weather: DailyRecommendationWeather
    @State private var showWeatherInfo = false

    var body: some View {
        HStack(spacing: 6) {
            WxWeatherIcon(condition: weather.condition, size: 18)
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

            // 天気の説明 (ウェザーニュース文言) をポップアップで見せる info ボタン
            Button {
                Haptic.impact(.light)
                showWeatherInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("天気の説明を表示")
            .popover(isPresented: $showWeatherInfo, arrowEdge: .top) {
                WeatherInfoPopover(weather: weather)
            }
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
    /// 朝いち演出 (1日1回) 用: true のとき1文字ずつ表示する
    var typewriter: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 13))
                .foregroundStyle(Color.orange.opacity(0.75))
            Group {
                if typewriter {
                    TypewriterText(text: text, lineSpacing: 3)
                } else {
                    Text(text)
                        .lineSpacing(3)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.primary)
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

// MARK: - タイプライター表示 (朝いち演出)

/// 全文ぶんのスペースを透明テキストで確保したまま1文字ずつ重ね描きする
/// (表示中にレイアウトが動かない)。text が変わると最初から再生する。
struct TypewriterText: View {
    let text: String
    var lineSpacing: CGFloat = 0
    /// 1文字あたりの表示間隔 (ナノ秒)。既定 ~18ms で 50字 ≈ 0.9秒
    var interval: UInt64 = 18_000_000

    @State private var visibleCount = 0

    var body: some View {
        Text(text)
            .lineSpacing(lineSpacing)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(String(text.prefix(visibleCount)))
                    .lineSpacing(lineSpacing)
            }
            .task(id: text) {
                visibleCount = 0
                while visibleCount < text.count {
                    try? await Task.sleep(nanoseconds: interval)
                    visibleCount += 1
                }
            }
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
    /// 透過アイテム画像の下地色 (詳細画面では白でくっきり見せる)。既定は透明。
    var background: Color = .clear

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(items.prefix(maxCount).enumerated()), id: \.offset) { _, owned in
                KFImage(URL(string: owned.image_url))
                    .placeholder { Color.gray.opacity(0.25) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .background(background)
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
