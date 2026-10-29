//
//  BrandMatchModels.swift
//  irodori
//
//  「あなたに合うブランド 10 選」のモデルと状態。本番 (API の値) と改善案 (サンプルの値) で共用する。
//  ブランドの事実は出典つきの調査マスタ (irodori-api/data/brand_master.json) の値だけを使う。
//

import SwiftUI
import Observation

// MARK: - ブランド (調査マスタ)

struct BMBrand: Identifiable {
    let id: String
    let nameEn: String
    let nameJa: String
    let segment: String
    /// 価格の段階 1 (プチプラ) 〜 5 (ラグジュアリー)
    let tier: Int
    /// 公式の通販などで見た定価の幅 (調査値)
    let priceRange: String?
    let foundedYear: Int?
    let founder: String?
    let company: String?
    let channels: [String]
    let styleTags: [String]
    let subTags: [String]
    let features: String?
    /// 特徴の最初の 1 文 (一覧で見せる。ブランドごとに違うので見比べやすい)
    let summary: String?
    let history: String?
    let position: String?
    let targetPersona: String?
    /// 流行・自己表現・社会調和・機能 (各 1〜5、IRODORI の見立て)
    let axes: [Double]
    let officialURL: String?
    /// ブランドの画像 (ロゴ → 運営会社のロゴ → デザイナー → 店舗・会社の写真 の順で見つかったもの)。無ければ頭文字
    let image: BMImage?

    var yen: String { String(repeating: "¥", count: tier) }
    /// 読み上げ用 (「¥¥¥」は「円円円」と読まれるため)
    var priceSpoken: String { "価格帯 5 段階中 \(tier)、\(tierLabel)" }
    var tierLabel: String { BMBrand.tierLabels[max(0, min(5, tier))] }
    /// 段階の目安 (調査で段階を決めたときの基準。トップスの通常の定価)
    var tierGuide: String { BMBrand.tierGuides[max(0, min(5, tier))] }

    static let tierLabels = ["", "プチプラ", "手頃", "ミドル", "ハイ", "ラグジュアリー"]
    /// proposals/brand-match/SCHEMA.md の price.tier の表 (シャツ・ブラウス・カットソー・ニット)
    static let tierGuides = ["", "〜3千円", "3千〜1万円", "1万〜2.5万円", "2.5万〜6万円", "6万円〜"]

    /// 公式の価格の例 (調査値) を「アイテム / 価格」に分ける。
    /// 例: 「シャツ 2千〜3千円台 / ジーンズ 3千〜4千円台」→ [(シャツ, 2千〜3千円台), (ジーンズ, 3千〜4千円台)]
    var priceExamples: [(item: String, price: String)] {
        guard let r = priceRange else { return [] }
        return r.components(separatedBy: " / ").compactMap { part in
            let t = part.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            // 数字で始まる語の手前で分ける (「GORE-TEX のレインジャケット 2万円台前半」も正しく分かれる)
            if let r = t.range(of: " (?=[0-9０-９])", options: .regularExpression) {
                return (String(t[..<r.lowerBound]), String(t[r.upperBound...]))
            }
            return ("", t)
        }
    }
}

// MARK: - ブランドの画像

enum BMImageKind {
    case brandLogo, companyLogo, designerPhoto, brandPhoto, companyPhoto, brandVisual, brandIcon

    /// 写真は枠いっぱいに、ロゴは余白をとって収める。
    /// 運営会社の画像はロゴの絵であることが多い (例: BAYCREW'S) ので、切らずに収める
    var isPhoto: Bool {
        switch self {
        case .designerPhoto, .brandPhoto, .brandVisual: return true
        case .brandLogo, .companyLogo, .companyPhoto, .brandIcon: return false
        }
    }
}

struct BMImage {
    /// 改善案: 開発用アセット (Preview Content/BrandMatchImages) の PNG 名。本番は空
    let file: String
    let kind: BMImageKind
    /// 何の画像か (例: ロゴ / 運営会社のロゴ（オンワード樫山） / デザイナー（三宅一生）)
    let label: String
    /// 白抜きのロゴ。黒い枠に置く
    let dark: Bool
    let source: String?
    let sourcePage: String?
    let license: String?
    /// 本番: API が配る画像 (irodori-api の /static/brands/<id>.png)
    var url: URL? = nil

    var uiImage: UIImage? {
        guard !file.isEmpty else { return nil }
        return Bundle.main.path(forResource: file, ofType: "png").flatMap { UIImage(contentsOfFile: $0) }
    }

    /// 枠の下端に付ける札 (ブランドのロゴでないことを示す)。ブランドのロゴなら nil
    var tag: String? {
        switch kind {
        case .brandLogo: return nil
        case .companyLogo, .companyPhoto: return "運営"
        case .designerPhoto: return "デザイナー"
        case .brandPhoto: return "店舗"
        case .brandVisual, .brandIcon: return "公式"
        }
    }
}

// MARK: - 10 選の 2 つの枠

/// API は 3 つの枠 (core / stretch / discover) で選ぶ。画面では「おすすめ」と「新しい出会い」の 2 つに分け、
/// 「少し背伸び」(stretch: 1 段上の価格や少し先の流行) は「新しい出会い」にまとめる (選ぶブランドの数は変えない)
enum BMSlot: String, CaseIterable, Identifiable {
    case core, discover
    var id: String { rawValue }

    init?(apiValue: String) {
        switch apiValue {
        case "core": self = .core
        case "stretch", "discover": self = .discover
        default: return nil
        }
    }

    /// 見出し (何の一覧かが一目でわかる言葉に)
    var title: String {
        switch self {
        case .core: return "おすすめ"
        case .discover: return "新しい出会い"
        }
    }

    /// 見出しの下の 1 行 (どう選んだか)
    var subtitle: String {
        switch self {
        case .core: return "好みも予算も、あなたに合うブランド"
        case .discover: return "少し上の価格や、クローゼットにまだ少ないテイストのブランド"
        }
    }
}

struct BMPick: Identifiable {
    let brand: BMBrand
    let slot: BMSlot
    /// 決まった言い回しの組み合わせ (brand_match.py の reasons)
    let reasons: [String]
    /// 一覧で並べる短い「合うところ」(流行に敏感・予算にぴったり・きれいめ など)
    let points: [String]
    let score: Double
    var id: String { brand.id }
    var brandID: String { brand.id }

    /// 一覧で見せる「合う理由」の短い一文 (例: トレンド感が近い・予算にぴったり)
    var reasonShort: String {
        let near: [String: String] = [
            "流行に敏感": "トレンド感が近い", "定番好き": "定番好きが近い", "自分らしさ": "自分らしさ重視が近い",
            "控えめ": "控えめな好みが近い", "きちんと感": "きちんと感が近い", "自由な装い": "自由な着こなしが近い",
            "着心地重視": "着心地重視が近い", "シルエット重視": "シルエット重視が近い", "価値観が近い": "好みが近い",
        ]
        let fit = points.lazy.compactMap { near[$0] }.first ?? "好みが近い"
        let price = points.contains("予算にぴったり") ? "予算にぴったり"
            : points.contains("手頃な価格") ? "手頃な価格" : points.contains("1 段上の価格") ? "少し上の価格" : nil
        return [fit, price].compactMap { $0 }.joined(separator: "・")
    }

    /// 一覧の行で見せる短い理由 (例: トレンド感が近い)。価格は ¥ の段階で別に見せる
    var reasonList: String {
        reasonShort.components(separatedBy: "・").first ?? reasonShort
    }

    /// テイスト (例: きれいめ・フェミニン)
    var tasteLine: String { brand.styleTags.prefix(2).joined(separator: "・") }

    /// 詳細で相棒が伝える「合う理由」。好み・価格・テイストの 3 つをハッシュタグにする。
    /// 言葉は API の points (短い言葉) と reasons (決まった言い回し) から組み、無い要素は飛ばす
    var reasonTags: [BMReasonTag] {
        let priceWords = ["予算にぴったり", "手頃な価格", "1 段上の価格"]
        let axisWords: Set<String> = ["流行に敏感", "定番好き", "自分らしさ", "控えめ", "きちんと感", "自由な装い",
                                      "着心地重視", "シルエット重視", "価値観が近い"]
        var out: [BMReasonTag] = []
        // 1. 好み (価値観がいちばん近い観点)
        if let a = points.first(where: { axisWords.contains($0) }) {
            let text = reasons.first { $0.contains("価値観が近い") } ?? "好みのバランスが、あなたと近い"
            out.append(BMReasonTag(tag: a, text: text))
        }
        // 2. 価格 (あなたの予算感との比べ)
        if let p = points.first(where: { priceWords.contains($0) }) {
            switch p {
            case "手頃な価格": out.append(BMReasonTag(tag: "手頃な価格", text: "手頃な価格で取り入れやすい"))
            case "1 段上の価格": out.append(BMReasonTag(tag: "ワンランク上", text: "少し背伸びして長く着る一着に"))
            default: out.append(BMReasonTag(tag: "予算にぴったり", text: "あなたの予算感にちょうどいい価格"))
            }
        }
        // 3. テイスト (クローゼットやタイプに合う雰囲気。無ければブランドのテイスト)
        if let t = points.first(where: { !axisWords.contains($0) && !priceWords.contains($0) }) {
            out.append(BMReasonTag(tag: t, text: reasons.first { $0.contains("「\(t)」") } ?? "「\(t)」のテイストのブランド"))
        } else if let t = brand.styleTags.first {
            out.append(BMReasonTag(tag: t, text: "「\(t)」のテイストのブランド"))
        }
        return out
    }
}

/// 合う理由の 1 つ (#流行に敏感 + 1 行の説明)
struct BMReasonTag: Identifiable {
    let tag: String
    let text: String
    var id: String { tag }
}

// MARK: - サンプルユーザー

struct BMPersona: Identifiable {
    let id: String
    let typeName: String
    let sub: String
    let typeCode: String
    /// 流行・自己表現・社会調和・機能 (ファッションタイプの点、各 1〜5)
    let scores: [Double]
    let economy: Double
    let closet: [String]
    let partnerLine: String
    let picks: [BMPick]

    /// 相棒の絵 (16 タイプの名前の画像)
    var iconName: String { "\(typeName)_icon" }
    var codeLabel: String { typeCode.map(String.init).joined(separator: "-") }
    func picks(in slot: BMSlot) -> [BMPick] { picks.filter { $0.slot == slot } }
}

// MARK: - 反応

enum BMReaction: String, CaseIterable, Identifiable {
    case like, owned, known, notInterested
    var id: String { rawValue }

    var title: String {
        switch self {
        case .like: return "好き"
        case .owned: return "持ってる"
        case .known: return "知ってた"
        case .notInterested: return "興味なし"
        }
    }

    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .owned: return "bag.fill"
        case .known: return "checkmark"
        case .notInterested: return "xmark"
        }
    }
}

// MARK: - 価格帯への返事

/// 「この価格帯、あなたにはどう？」への返事。並びはメーターと同じ (左が安い)
enum BMPriceVerdict: String, CaseIterable, Identifiable {
    case low, just, high
    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "安い"
        case .just: return "ちょうどいい"
        case .high: return "高い"
        }
    }

    /// 相棒の返事の書き出し
    var ack: String {
        switch self {
        case .low: return "もっと上でも大丈夫なんだね、覚えたよ。"
        case .just: return "ちょうどいいんだね、覚えたよ。"
        case .high: return "高めなんだね、覚えたよ。"
        }
    }
}

/// 返事を送ったあとに相棒が覚えたこと (本番だけ。改善案では nil)
struct BMPriceLearning {
    /// 予算感 (1〜5) の前と後
    let budgetBefore: Double
    let budgetAfter: Double
    /// 10 選のうち入れ替わったブランドの数
    let changed: Int
    /// 相棒の理解度が増えた分 (ミッション「ブランドの価格帯を教える」)
    let gainedPct: Int
    /// 価格帯を教えた回数と、次に理解度が上がる回数
    let answers: Int
    let nextTarget: Int?

    /// 相棒の返事の続き (予算感の動き + 10 選がどうなったか)
    var detail: String {
        let move = budgetAfter < budgetBefore - 0.01 ? "予算感を少し下げて、"
            : budgetAfter > budgetBefore + 0.01 ? "予算感を少し上げて、" : ""
        let list = changed > 0 ? "10 選のうち \(changed) ブランドを選び直したよ" : "いまの 10 選はこのままがよさそう"
        return move + list
    }
}

// MARK: - 状態

@Observable
final class BrandMatchStore {
    var persona: BMPersona
    /// 反応が変わったとき (本番: API に送る)。nil = 送らない (改善案)
    var onReaction: ((String, BMReaction?) -> Void)?
    /// "personaID/brandID" → 反応
    private(set) var reactions: [String: BMReaction] = [:]
    /// "personaID/brandID" → 価格帯への返事
    private(set) var priceVerdicts: [String: BMPriceVerdict] = [:]
    /// 価格帯への返事を送り、選び直した 10 選に入れ替える (本番)。nil = 送らない (改善案)
    var onPriceFeedback: (@MainActor (String, BMPriceVerdict?) async -> BMPriceLearning?)?
    /// 一覧の見出しの下に出す相棒のひとこと (選び直したときなど)。nil なら決まった文
    var note: String?

    init(persona: BMPersona) {
        self.persona = persona
    }

    func reaction(_ brandID: String) -> BMReaction? { reactions["\(persona.id)/\(brandID)"] }

    func toggle(_ r: BMReaction, for brandID: String) {
        let key = "\(persona.id)/\(brandID)"
        let next: BMReaction? = reactions[key] == r ? nil : r
        reactions[key] = next
        Haptic.selection()
        onReaction?(brandID, next)
    }

    func set(_ r: BMReaction?, for brandID: String) {
        reactions["\(persona.id)/\(brandID)"] = r
        onReaction?(brandID, r)
    }

    /// サーバーに残っている反応を、送り返さずに読み込む
    func preload(_ r: BMReaction, for brandID: String) {
        reactions["\(persona.id)/\(brandID)"] = r
    }

    func priceVerdict(_ brandID: String) -> BMPriceVerdict? { priceVerdicts["\(persona.id)/\(brandID)"] }

    /// サーバーに残っている価格帯への返事を、送り返さずに読み込む
    func preloadPrice(_ v: BMPriceVerdict, for brandID: String) {
        priceVerdicts["\(persona.id)/\(brandID)"] = v
    }

    /// 価格帯に返事する (同じ返事をもう一度押すと取り消し)。相棒が覚えたことを返す
    @MainActor
    func answerPrice(_ v: BMPriceVerdict, for brandID: String) async -> (verdict: BMPriceVerdict?, learning: BMPriceLearning?) {
        let key = "\(persona.id)/\(brandID)"
        let previous = priceVerdicts[key]
        let next: BMPriceVerdict? = previous == v ? nil : v
        priceVerdicts[key] = next
        Haptic.selection()
        guard let send = onPriceFeedback else { return (next, nil) }
        let learning = await send(brandID, next)
        // 届かなかったときは元に戻す (覚えていないのに選んだ見た目にしない)
        if learning == nil { priceVerdicts[key] = previous }
        return (next, learning)
    }

    func count(_ r: BMReaction) -> Int {
        persona.picks.filter { reaction($0.brandID) == r }.count
    }

    func resetPersona() {
        reactions = reactions.filter { !$0.key.hasPrefix("\(persona.id)/") }
    }
}
