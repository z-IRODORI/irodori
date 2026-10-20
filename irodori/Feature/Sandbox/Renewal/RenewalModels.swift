//
//  RenewalModels.swift
//  irodori - Sandbox
//
//  リニューアル後アプリ体験 Sandbox のドメインモデル。
//  設計書 01〜04 (app_ecosystem / partner_communication / partner_action_stock / onboarding) の
//  「4つのコア機能 × 3層行動ストック × 口調5種」を、API なしで端末内だけで再現するための型。
//
//  ※ 商品名・ブランド・価格は一切持たない。アイテムは「白シャツ」のような一般名詞だけ。
//

import SwiftUI

// MARK: - デザイントークン (TasteTokens と同値。Sandbox 単体でビルドできるよう複製)

enum RenewalTokens {
    static let ground = Color(red: 0xF9 / 255, green: 0xFA / 255, blue: 0xFB / 255)     // #F9FAFB
    static let surface = Color.white
    static let raised = Color(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF7 / 255)     // #F6F6F7
    static let border = Color(red: 0xE8 / 255, green: 0xE8 / 255, blue: 0xE8 / 255)     // #E8E8E8
    static let rule = Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255)       // #EFEFEF
    static let controlBorder = Color(red: 0xD1 / 255, green: 0xD5 / 255, blue: 0xDB / 255) // #D1D5DB
    static let ink = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)        // #111111
    static let muted = Color(red: 0x5F / 255, green: 0x63 / 255, blue: 0x68 / 255)      // #5F6368 (白地で AA 以上)
    static let primaryFill = Color(red: 0x1D / 255, green: 0x1F / 255, blue: 0x20 / 255) // #1D1F20
    static let learned = Color(red: 0x1D / 255, green: 0x5F / 255, blue: 0xBF / 255)    // #1D5FBF 「行動から学習」の印
    static let discovery = Color.teal                                                   // 発見枠 (既存ホームと同じ)
    static let accentPink = Color(red: 0xD8 / 255, green: 0x1B / 255, blue: 0x60 / 255) // #D81B60 イチオシ・きらめき (既存ホームのピンク。白地で AA)
    static let owned = ink                                                              // 手持ちの印 (色は足さず、影と黒のチェックで示す)

    static let cardRadius: CGFloat = 10
    static let controlRadius: CGFloat = 6
    static let chipRadius: CGFloat = 4
    static let edge: CGFloat = 24
}

// MARK: - 初回4問 (onboarding_and_data_flow_design.md Step 1)

/// Q1 外向きの印象。値は既存 PartnerOnboardingQuestion と同じ (soft / refined / unique / clean)
enum RenewalImpression: String, Codable, CaseIterable, Identifiable {
    case soft, refined, unique, clean
    var id: String { rawValue }

    var label: String {
        switch self {
        case .soft: return "親しみやすく、柔和な印象"
        case .refined: return "知的で、凛とした大人っぽい印象"
        case .unique: return "自分らしいセンスがある印象"
        case .clean: return "清潔感があり、誠実な印象"
        }
    }
    var sub: String {
        switch self {
        case .soft: return "話しかけやすい・穏やか"
        case .refined: return "洗練・落ち着き"
        case .unique: return "埋もれない・粋"
        case .clean: return "きちんとしている・安心感"
        }
    }
    /// セリフに差し込む短い言い方
    var shortWord: String {
        switch self {
        case .soft: return "親しみやすい人"
        case .refined: return "知的で凛とした人"
        case .unique: return "センスのある人"
        case .clean: return "清潔感のある人"
        }
    }
    /// 推薦で優先する色の系統
    var preferredFamilies: [RenewalColorFamily] {
        switch self {
        case .soft: return [.earth, .mono, .denim]
        case .refined: return [.mono, .navy]
        case .unique: return [.accent, .earth, .denim]
        case .clean: return [.navy, .mono]
        }
    }
}

/// Q2 内向きの感覚 (F 機能 / A 美学)
enum RenewalPriority: String, Codable, CaseIterable, Identifiable {
    case F, A
    var id: String { rawValue }
    var label: String {
        self == .F ? "身体的なストレスのなさ" : "鏡を見たときの高揚感"
    }
    var sub: String {
        self == .F ? "締め付けがない・動きやすい・着心地の良さを最優先" : "少し背筋が伸びても、シルエットが美しく見えることを最優先"
    }
    /// セリフに差し込む「大事にしている価値」
    var valueWord: String { self == .F ? "着心地のよさ" : "きれいなシルエット" }
}

/// Q3 提案の振れ幅 (C 定番 / T 変化)
enum RenewalRange: String, Codable, CaseIterable, Identifiable {
    case C, T
    var id: String { rawValue }
    var label: String { self == .C ? "安心できる「定番の深掘り」" : "マンネリを破る「新しい発見」" }
    var sub: String {
        self == .C ? "似合う軸をぶらさず、手持ち服の着回し力を高めたい" : "旬の要素や新鮮な組み合わせを知りたい"
    }
    var stance: String { self == .C ? "手持ちの定番を深掘り" : "新しい組み合わせも提案" }
}

/// Q4 / 口調。partner_action_stock_and_growth_design.md §5 の5種 (最新設計を優先)
enum RenewalTone: String, Codable, CaseIterable, Identifiable {
    case gentle, casual, cool, spicy, kansai
    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: return "やさしく丁寧"
        case .casual: return "フレンドリー"
        case .cool: return "クール・簡潔"
        case .spicy: return "ちょっと辛口"
        case .kansai: return "関西弁"
        }
    }
    var character: String {
        switch self {
        case .gentle: return "穏やかで肯定感が高く、毎朝心地よく寄り添う"
        case .casual: return "気軽に話せて、一緒に服選びを楽しむ"
        case .cool: return "感情表現を省き、要点だけをロジカルに伝える"
        case .spicy: return "迷う背中をビシッと押す、愛のある辛口"
        case .kansai: return "温かみがあって緊張をほぐしてくれる"
        }
    }
}

struct RenewalAnswers: Codable, Equatable {
    var impression: RenewalImpression = .soft
    var priority: RenewalPriority = .F
    var range: RenewalRange = .C
    var tone: RenewalTone = .gentle

    /// 既存の 16 タイプ判定ロジック (PartnerOnboardingResponse.mock) をそのまま使う
    var typeName: String {
        PartnerOnboardingResponse.mock(
            impression: impression.rawValue,
            priority: priority.rawValue,
            rangeVal: range.rawValue,
            tone: "gentle"
        ).type_name
    }
}

// MARK: - アイテム

enum RenewalCategory: String, Codable, CaseIterable, Identifiable {
    case top, bottom, outer, shoes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .top: return "トップス"
        case .bottom: return "ボトムス"
        case .outer: return "羽織り"
        case .shoes: return "靴"
        }
    }
}

enum RenewalColorFamily: String, Codable, CaseIterable {
    case mono, navy, earth, denim, accent
    var label: String {
        switch self {
        case .mono: return "モノトーン"
        case .navy: return "ネイビー"
        case .earth: return "ベージュ・ブラウン"
        case .denim: return "デニム"
        case .accent: return "差し色"
        }
    }
    /// 着こなしイメージの雰囲気文 (pinterest_vibe 相当)
    var vibe: String {
        switch self {
        case .mono: return "袖を軽くまくった、抜け感のあるモノトーン"
        case .navy: return "清潔感のあるネイビー基調"
        case .earth: return "柔らかいベージュのワントーン"
        case .denim: return "肩の力が抜けたデニム合わせ"
        case .accent: return "差し色をひとつ効かせた大人カジュアル"
        }
    }
}

enum RenewalItemSource: String, Codable {
    case photo      // 写真フォルダから AI 発掘
    case staple     // 定番タップ・検索
    case camera     // カメラで全身スナップ
    case ownedTap   // 推薦詳細の「似た服を持ってる」
    case preset     // Sandbox のシナリオ投入
}

/// 一般名詞だけの定番アイテム (ブランド・商品名・価格は持たない)
struct RenewalStaple: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let category: RenewalCategory
    let family: RenewalColorFamily
    let hex: UInt32

    var color: Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    /// 白っぽい色は枠線を付けないと背景に溶ける
    var isLight: Bool { ((hex >> 16) & 0xFF) > 0xE0 && ((hex >> 8) & 0xFF) > 0xE0 }

    static let catalog: [RenewalStaple] = [
        // トップス
        .init(id: "top_white_tee", name: "白T", category: .top, family: .mono, hex: 0xF4F4F2),
        .init(id: "top_white_shirt", name: "白シャツ", category: .top, family: .mono, hex: 0xFAFAF8),
        .init(id: "top_black_tee", name: "黒T", category: .top, family: .mono, hex: 0x222222),
        .init(id: "top_gray_sweat", name: "グレースウェット", category: .top, family: .mono, hex: 0x9A9A9A),
        .init(id: "top_navy_knit", name: "ネイビーニット", category: .top, family: .navy, hex: 0x26324F),
        .init(id: "top_beige_knit", name: "ベージュニット", category: .top, family: .earth, hex: 0xD9C7A7),
        .init(id: "top_stripe_shirt", name: "ストライプシャツ", category: .top, family: .navy, hex: 0xB9C8DE),
        .init(id: "top_green_knit", name: "グリーンニット", category: .top, family: .accent, hex: 0x4E6B4F),
        // ボトムス
        .init(id: "btm_black_slacks", name: "黒スラックス", category: .bottom, family: .mono, hex: 0x1E1E1E),
        .init(id: "btm_denim", name: "デニムパンツ", category: .bottom, family: .denim, hex: 0x4A6C96),
        .init(id: "btm_beige_chino", name: "ベージュチノ", category: .bottom, family: .earth, hex: 0xC9B48E),
        .init(id: "btm_gray_slacks", name: "グレースラックス", category: .bottom, family: .mono, hex: 0x7C7C7C),
        .init(id: "btm_navy_slacks", name: "ネイビースラックス", category: .bottom, family: .navy, hex: 0x232C45),
        .init(id: "btm_white_pants", name: "白パンツ", category: .bottom, family: .mono, hex: 0xF2F0EA),
        // 羽織り
        .init(id: "out_navy_cardigan", name: "ネイビーカーディガン", category: .outer, family: .navy, hex: 0x2A3557),
        .init(id: "out_green_cardigan", name: "グリーンカーディガン", category: .outer, family: .accent, hex: 0x5C7A55),
        .init(id: "out_beige_trench", name: "ベージュトレンチ", category: .outer, family: .earth, hex: 0xC8AE82),
        .init(id: "out_black_jacket", name: "黒ジャケット", category: .outer, family: .mono, hex: 0x262626),
        .init(id: "out_denim_jacket", name: "デニムジャケット", category: .outer, family: .denim, hex: 0x5878A3),
        // 靴
        .init(id: "sho_white_sneaker", name: "白スニーカー", category: .shoes, family: .mono, hex: 0xF5F5F5),
        .init(id: "sho_black_sneaker", name: "黒スニーカー", category: .shoes, family: .mono, hex: 0x2A2A2A),
        .init(id: "sho_black_loafer", name: "黒ローファー", category: .shoes, family: .mono, hex: 0x1A1A1A),
        .init(id: "sho_brown_boots", name: "ブラウンブーツ", category: .shoes, family: .earth, hex: 0x6B4A33),
    ]

    static func find(_ id: String) -> RenewalStaple? { catalog.first { $0.id == id } }
}

/// クローゼットに入った手持ちアイテム
struct RenewalOwnedItem: Codable, Hashable, Identifiable {
    let staple: RenewalStaple
    let addedDay: Int
    let source: RenewalItemSource

    var id: String { staple.id }
    var name: String { staple.name }
    var category: RenewalCategory { staple.category }
    var family: RenewalColorFamily { staple.family }
}

// MARK: - 着用記録・行動ログ

enum RenewalWearSource: String, Codable {
    case decided    // 「今日着る」で決定
    case photo      // 写真フォルダから (撮影日で過去に配置)
    case camera     // 全身スナップ
}

struct RenewalWearRecord: Codable, Hashable, Identifiable {
    var id: String { "\(day)" }
    let day: Int
    let itemIDs: [String]
    let source: RenewalWearSource
    let isDiscovery: Bool
}

enum RenewalActionType: String, Codable {
    case wearDecided = "wear_decided"
    case itemAdded = "item_added"
    case disliked
    case liked
    case pivot
    case toneChanged = "tone_changed"
    case tasteVote = "taste_vote"
}

/// USER_ACTION_LOG 相当。learnedSummary が「相棒が新しく覚えたこと」に出る1行メモ
struct RenewalActionLog: Codable, Hashable, Identifiable {
    var id = UUID()
    let day: Int
    let type: RenewalActionType
    let action: String
    let learned: String
}

enum RenewalDislikeReason: String, Codable, CaseIterable, Identifiable {
    case cold, color, style, mood
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cold: return "寒そう"
        case .color: return "色が好みじゃない"
        case .style: return "系統が違う"
        case .mood: return "今日は気分じゃない"
        }
    }
}

struct RenewalDislike: Codable, Hashable {
    let day: Int
    let reason: RenewalDislikeReason
    let families: [RenewalColorFamily]
    let recipeKey: String
}

// MARK: - 日替わり着眼点 (デイリー・アングル)

enum RenewalDailyAngle: String, Codable {
    case birth      // Stage 1: 手持ち0着
    case newItem    // A. 新着アイテム主役日
    case rotation   // B. カレンダー着回し日
    case rescue     // C. 眠っている服の救出日
    case weather    // D. 天気・寒暖差ケア日
    case weekend    // E. 週末の気分転換日

    var label: String {
        switch self {
        case .birth: return "4問の指針から"
        case .newItem: return "A. 新着アイテム主役日"
        case .rotation: return "B. カレンダー着回し日"
        case .rescue: return "C. 眠っている服の救出日"
        case .weather: return "D. 天気・寒暖差ケア日"
        case .weekend: return "E. 週末の気分転換日"
        }
    }
}

// MARK: - 天気 (Sandbox 用の固定サンプル)

struct RenewalWeather: Equatable {
    let tempMax: Int
    let tempMin: Int
    let condition: String
    let diffFromYesterday: Int

    var isRain: Bool { condition == "雨" }
    var symbol: String {
        switch condition {
        case "晴れ": return "sun.max"
        case "くもり": return "cloud"
        case "雨": return "cloud.rain"
        default: return "cloud.sun"
        }
    }
    /// 羽織りが必要か
    var needsOuter: Bool { tempMax <= 17 || (isRain && tempMax <= 19) }

    private static let sequence: [(Int, Int, String)] = [
        (20, 13, "晴れ"), (16, 11, "くもり"), (16, 10, "雨"), (21, 14, "晴れ"),
        (22, 15, "晴れ"), (19, 12, "くもり"), (24, 16, "晴れ"), (15, 9, "くもり"),
        (18, 11, "晴れ"), (21, 13, "晴れ"),
    ]

    static func forDay(_ day: Int) -> RenewalWeather {
        func raw(_ d: Int) -> (Int, Int, String) {
            let n = sequence.count
            return sequence[((d % n) + n) % n]
        }
        let today = raw(day)
        let yesterday = raw(day - 1)
        return RenewalWeather(tempMax: today.0, tempMin: today.1, condition: today.2, diffFromYesterday: today.0 - yesterday.0)
    }
}

// MARK: - 推薦レシピ (手持ち起点)

struct RenewalRecipe: Hashable, Identifiable {
    enum Kind: Hashable { case owned, partial, zero, discovery }

    let ownedItems: [RenewalOwnedItem]
    let missingItems: [RenewalStaple]
    let kind: Kind
    let heroID: String?
    let mainFamily: RenewalColorFamily

    /// 推薦カードの同一性 (決定済み・♡ の判定に使う)
    var key: String {
        (ownedItems.map(\.id) + missingItems.map { "m:" + $0.id }).sorted().joined(separator: "|")
    }
    var id: String { key }

    var allStaples: [RenewalStaple] { ownedItems.map(\.staple) + missingItems }
    var isDiscovery: Bool { kind == .discovery }

    /// カード上部の状態ラベル
    var statusLabel: String {
        let owned = ownedItems.count
        if missingItems.isEmpty { return "手持ちの\(owned)点で再現できます" }
        if owned == 0 { return "定番で組んだ案 (手持ちはまだ0点)" }
        let missingLabel = missingItems.count == 1 ? missingItems[0].category.label : "アイテム"
        return "手持ち\(owned)点 ＋ \(missingLabel)\(missingItems.count)点"
    }

    /// 2点を「白シャツ×黒スラックス」の形で言う
    var pairText: String {
        let names = (ownedItems.isEmpty ? missingItems.map(\.name) : ownedItems.map(\.name))
        return names.prefix(2).joined(separator: "×")
    }
}

// MARK: - 予定の対象 (今日 / 明日 / 週末)

enum RenewalScope: String, CaseIterable, Identifiable {
    case today, tomorrow, weekend
    var id: String { rawValue }
    var label: String {
        switch self {
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .weekend: return "週末"
        }
    }
    /// 「次に着る日」。15時までは今日、それ以降は明日の服を提案する (選択肢は出さない)
    static func next(now: Date = Date()) -> RenewalScope {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal.component(.hour, from: now) < 15 ? .today : .tomorrow
    }
    var actionLabel: String {
        switch self {
        case .today: return "今日着る"
        case .tomorrow: return "明日着る"
        case .weekend: return "週末に着る"
        }
    }
}
