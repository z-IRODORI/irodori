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
    var tierLabel: String { ["", "プチプラ", "手頃", "ミドル", "ハイ", "ラグジュアリー"][max(0, min(5, tier))] }
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

// MARK: - 10 選の 3 つの枠

enum BMSlot: String, CaseIterable, Identifiable {
    case core, stretch, discover
    var id: String { rawValue }

    /// 見出し (何の一覧かが一目でわかる言葉に)
    var title: String {
        switch self {
        case .core: return "いちばん合う"
        case .stretch: return "少し背伸び"
        case .discover: return "新しい出会い"
        }
    }

    /// 見出しの下の 1 行 (どう選んだか)
    var subtitle: String {
        switch self {
        case .core: return "好みも予算も、あなたにぴったりのブランド"
        case .stretch: return "いつもより少し上の価格や、少し先のトレンドに挑戦"
        case .discover: return "クローゼットにまだ少ないテイストのブランド"
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

// MARK: - 状態

@Observable
final class BrandMatchStore {
    var persona: BMPersona
    /// 反応が変わったとき (本番: API に送る)。nil = 送らない (改善案)
    var onReaction: ((String, BMReaction?) -> Void)?
    /// "personaID/brandID" → 反応
    private(set) var reactions: [String: BMReaction] = [:]

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

    func count(_ r: BMReaction) -> Int {
        persona.picks.filter { reaction($0.brandID) == r }.count
    }

    func resetPersona() {
        reactions = reactions.filter { !$0.key.hasPrefix("\(persona.id)/") }
    }
}
