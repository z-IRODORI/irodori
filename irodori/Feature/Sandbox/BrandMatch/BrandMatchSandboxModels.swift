//
//  BrandMatchSandboxModels.swift
//  irodori - Sandbox
//
//  「あなたに合うブランド 10 選」の改善案 (A〜D) で共用するモデルと状態。
//  ブランドの事実は BrandMatchSandboxData.swift (出典つきの調査マスタから書き出したもの) の値だけを使う。
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

    /// 写真は枠いっぱいに、ロゴは余白をとって収める
    var isPhoto: Bool {
        switch self {
        case .designerPhoto, .brandPhoto, .companyPhoto, .brandVisual: return true
        case .brandLogo, .companyLogo, .brandIcon: return false
        }
    }
}

struct BMImage {
    /// 開発用アセット (Preview Content/BrandMatchImages) の PNG。配布用のビルドには入らない
    let file: String
    let kind: BMImageKind
    /// 何の画像か (例: ロゴ / 運営会社のロゴ（オンワード樫山） / デザイナー（三宅一生）)
    let label: String
    /// 白抜きのロゴ。黒い枠に置く
    let dark: Bool
    let source: String?
    let sourcePage: String?
    let license: String?

    var uiImage: UIImage? {
        Bundle.main.path(forResource: file, ofType: "png").flatMap { UIImage(contentsOfFile: $0) }
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

    var title: String {
        switch self {
        case .core: return "ど真ん中"
        case .stretch: return "ちょっと背伸び"
        case .discover: return "はじめまして"
        }
    }

    var subtitle: String {
        switch self {
        case .core: return "価値観も予算も、いちばん近い"
        case .stretch: return "1 段上の価格か、少し先の流行"
        case .discover: return "クローゼットにまだ少ない雰囲気"
        }
    }
}

struct BMPick: Identifiable {
    let brandID: String
    let slot: BMSlot
    /// 決まった言い回しの組み合わせ (brand_match.py の reasons)
    let reasons: [String]
    /// 一覧で並べる短い「合うところ」(流行に敏感・予算にぴったり・きれいめ など)
    let points: [String]
    let score: Double
    var id: String { brandID }
    var brand: BMBrand { BMBrand.all[brandID]! }
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
final class BMSandboxStore {
    var personaIndex = 0
    /// "personaID/brandID" → 反応
    private(set) var reactions: [String: BMReaction] = [:]

    var persona: BMPersona { BMPersona.samples[personaIndex] }

    func reaction(_ brandID: String) -> BMReaction? { reactions["\(persona.id)/\(brandID)"] }

    func toggle(_ r: BMReaction, for brandID: String) {
        let key = "\(persona.id)/\(brandID)"
        reactions[key] = reactions[key] == r ? nil : r
        Haptic.selection()
    }

    func set(_ r: BMReaction?, for brandID: String) {
        reactions["\(persona.id)/\(brandID)"] = r
    }

    func count(_ r: BMReaction) -> Int {
        persona.picks.filter { reaction($0.brandID) == r }.count
    }

    func resetPersona() {
        reactions = reactions.filter { !$0.key.hasPrefix("\(persona.id)/") }
    }
}
