//
//  RenewalFirstViewLayouts.swift
//  irodori - Sandbox
//
//  ホームのファーストビューで3案を見せるレイアウトと、各案の「見せ方」。
//  検証の結果、レイアウトは「リスト」(本命) と「のぞき見カルーセル」の2つに絞った。
//
//  見せ方 (RenewalVisualMode)
//   - 写真         : コーデモデル (Pinterest) の写真
//   - 手持ち＋コーデモデル : 手持ちアイテムを並べ、足りない分だけコーデモデルから抽出したアイテムで埋める
//   - コーデモデルのアイテム: コーデモデルから抽出したアイテムをそのまま並べ、手持ちにあるものに印を付ける
//  抽出はサーバ側で Nano Banana (outfit_item_generator と同じロジック) がバックグラウンド実行し、
//  切り抜き → 商品風画像 の順に差し替わる。
//

import SwiftUI
import Kingfisher

enum RenewalFirstViewLayout: String, CaseIterable, Identifiable {
    case list, peek

    var id: String { rawValue }
    static let storageKey = "renewalSandbox.firstViewLayout.v2"

    var label: String { self == .list ? "リスト" : "のぞき見" }
}

enum RenewalVisualMode: String, CaseIterable, Identifiable {
    case photo, ownedPlusExample, exampleItems

    var id: String { rawValue }
    static let storageKey = "renewalSandbox.visualMode.v2"

    var label: String {
        switch self {
        case .photo: return "写真"
        case .ownedPlusExample: return "提案アイテム"
        case .exampleItems: return "コーデモデルのアイテム (推奨)"
        }
    }

    var summary: String {
        switch self {
        case .photo: return "コーデモデル (Pinterest) の写真で雰囲気を見せる"
        case .ownedPlusExample: return "手持ちの服を並べ、足りない分だけコーデモデルのアイテムで埋める"
        case .exampleItems: return "コーデモデルのアイテムを並べ、手持ちにあるものに印を付ける"
        }
    }
}

/// 3案の表示に必要な操作 (どのレイアウトでも共通)
struct RenewalRecipeActions {
    let scope: RenewalScope
    let decidedId: String?
    let isSending: Bool
    let showCharCount: Bool
    let visualMode: RenewalVisualMode
    let extraction: (OwnedFirstRecipe) -> OwnedFirstExtraction?
    let onDetail: (OwnedFirstRecipe) -> Void
    let onDecide: (OwnedFirstRecipe) -> Void
    let onPivot: () -> Void

    func isDecided(_ r: OwnedFirstRecipe) -> Bool { decidedId == r.recipe_id }
}

// MARK: - 切替メニュー (Sandbox 用)

/// ナビバー右上の「表示の切替」メニュー (ファーストビューの縦幅を使わない)
struct RenewalViewModeMenu: View {
    @Binding var layoutRaw: String
    @Binding var visualRaw: String

    var body: some View {
        Menu {
            Picker("レイアウト", selection: $layoutRaw) {
                ForEach(RenewalFirstViewLayout.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.inline)
            Picker("見せ方", selection: $visualRaw) {
                ForEach(RenewalVisualMode.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(RenewalTokens.ink)
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("表示の切替")
    }
}

// MARK: - 共通の小部品

/// イチオシ: 既存ホーム (DailyIchioshiBadge) と同じピンクのきらめきバッジ
private struct PickTag: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkle").font(.system(size: 10, weight: .semibold))
            Text("イチオシ").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(RenewalTokens.accentPink)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(RenewalTokens.accentPink.opacity(0.35), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }
}

// MARK: - 彩り (アイテムの色)

/// アイテム名の色の言葉から表示用の色を引く (服の色の見本。厳密な色ではない)
enum RenewalColorPalette {
    private static let table: [(String, String, Color)] = [
        ("ライトブルー", "ライトブルー", Color(red: 0.61, green: 0.76, blue: 0.90)),
        ("サックス", "サックス", Color(red: 0.61, green: 0.76, blue: 0.90)),
        ("ライトベージュ", "ベージュ", Color(red: 0.87, green: 0.80, blue: 0.69)),
        ("オフホワイト", "ホワイト", Color(red: 0.96, green: 0.95, blue: 0.92)),
        ("ホワイト", "ホワイト", Color(red: 0.97, green: 0.97, blue: 0.96)),
        ("白", "ホワイト", Color(red: 0.97, green: 0.97, blue: 0.96)),
        ("ブラック", "ブラック", Color(red: 0.13, green: 0.13, blue: 0.13)),
        ("黒", "ブラック", Color(red: 0.13, green: 0.13, blue: 0.13)),
        ("チャコール", "グレー", Color(red: 0.36, green: 0.37, blue: 0.39)),
        ("ダークグレー", "グレー", Color(red: 0.36, green: 0.37, blue: 0.39)),
        ("グレー", "グレー", Color(red: 0.62, green: 0.64, blue: 0.67)),
        ("ネイビー", "ネイビー", Color(red: 0.13, green: 0.21, blue: 0.36)),
        ("ブルー", "ブルー", Color(red: 0.25, green: 0.44, blue: 0.71)),
        ("デニム", "ブルー", Color(red: 0.25, green: 0.44, blue: 0.71)),
        ("ベージュ", "ベージュ", Color(red: 0.85, green: 0.76, blue: 0.64)),
        ("キャメル", "キャメル", Color(red: 0.73, green: 0.53, blue: 0.32)),
        ("ブラウン", "ブラウン", Color(red: 0.48, green: 0.31, blue: 0.20)),
        ("茶", "ブラウン", Color(red: 0.48, green: 0.31, blue: 0.20)),
        ("カーキ", "カーキ", Color(red: 0.45, green: 0.45, blue: 0.27)),
        ("オリーブ", "カーキ", Color(red: 0.45, green: 0.45, blue: 0.27)),
        ("グリーン", "グリーン", Color(red: 0.27, green: 0.50, blue: 0.34)),
        ("緑", "グリーン", Color(red: 0.27, green: 0.50, blue: 0.34)),
        ("オレンジ", "オレンジ", Color(red: 0.88, green: 0.48, blue: 0.20)),
        ("テラコッタ", "テラコッタ", Color(red: 0.78, green: 0.40, blue: 0.27)),
        ("レッド", "レッド", Color(red: 0.75, green: 0.22, blue: 0.20)),
        ("ボルドー", "ボルドー", Color(red: 0.45, green: 0.12, blue: 0.18)),
        ("赤", "レッド", Color(red: 0.75, green: 0.22, blue: 0.20)),
        ("イエロー", "イエロー", Color(red: 0.91, green: 0.78, blue: 0.30)),
        ("マスタード", "マスタード", Color(red: 0.80, green: 0.62, blue: 0.18)),
        ("ピンク", "ピンク", Color(red: 0.91, green: 0.63, blue: 0.71)),
        ("パープル", "パープル", Color(red: 0.49, green: 0.36, blue: 0.65)),
        ("ラベンダー", "ラベンダー", Color(red: 0.73, green: 0.67, blue: 0.85)),
    ]

    struct Swatch: Hashable { let name: String; let color: Color }

    static func swatch(for label: String) -> Swatch? {
        table.first { label.contains($0.0) }.map { Swatch(name: $0.1, color: $0.2) }
    }

    /// 案のアイテムから重複なしの色の並び (最大4色)
    static func swatches(_ r: OwnedFirstRecipe) -> [Swatch] {
        var seen: [Swatch] = []
        for label in r.owned_items.map(\.label) + r.missing_items.map(\.label) {
            if let sw = swatch(for: label), !seen.contains(where: { $0.name == sw.name }) { seen.append(sw) }
        }
        return Array(seen.prefix(4))
    }
}

/// 見出しの下に添える、そのコーデの「彩り」(色の見本と色名)
struct RenewalPaletteRow: View {
    let swatches: [RenewalColorPalette.Swatch]

    var body: some View {
        if !swatches.isEmpty {
            HStack(spacing: 6) {
                HStack(spacing: -4) {
                    ForEach(swatches, id: \.name) { sw in
                        Circle()
                            .fill(sw.color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .overlay(Circle().stroke(RenewalTokens.border, lineWidth: 0.5).padding(-0.75))
                    }
                }
                Text(swatches.map(\.name).joined(separator: " × "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("色の組み合わせ: " + swatches.map(\.name).joined(separator: "、"))
        }
    }
}

/// 手持ち (濃い) と買い足す (点線) を1コマずつ並べた、完成までの目盛り
struct RenewalCompletionSegments: View {
    let owned: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i < owned ? RenewalTokens.ink : Color.clear)
                    .overlay(Capsule().strokeBorder(i < owned ? Color.clear : RenewalTokens.controlBorder,
                                                    style: StrokeStyle(lineWidth: 1, dash: [2, 1.5])))
                    .frame(width: 14, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 気温に合わない服への注意 (指名された服など)
private struct ClimateWarningText: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "thermometer.medium")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(red: 0.70, green: 0.33, blue: 0.04)) // #B45309 (白地で AA)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 小さめの決定ボタン (見た目 36pt、タップ領域 44pt)
private struct CompactDecideButton: View {
    let recipe: OwnedFirstRecipe
    let actions: RenewalRecipeActions
    var fullWidth = false

    var body: some View {
        let decided = actions.isDecided(recipe)
        Button {
            if !decided { actions.onDecide(recipe) }
        } label: {
            HStack(spacing: 4) {
                if decided { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                Text(decided ? "決定済み" : actions.scope.actionLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(decided ? RenewalTokens.ink : .white)
            .padding(.horizontal, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
            .background(decided ? RenewalTokens.surface : RenewalTokens.primaryFill)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.controlRadius + 2)
                .stroke(decided ? RenewalTokens.controlBorder : Color.clear, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(actions.isSending)
    }
}

/// 手持ち (実線) + 未所持 (点線) の小さなアイテム列
private struct ItemStrip: View {
    let recipe: OwnedFirstRecipe
    var size: CGFloat
    var limit: Int = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(recipe.owned_items.prefix(limit)) { item in
                RenewalRemoteItemTile(label: item.label, imageURL: item.image_url, slot: item.slot, size: size, owned: true, showName: false)
            }
            ForEach(recipe.missing_items.prefix(max(0, limit - recipe.owned_items.count))) { m in
                RenewalRemoteItemTile(label: m.label, imageURL: nil, slot: m.slot, size: size, owned: false, showName: false)
            }
        }
    }
}

/// 見せ方に応じたステータス。「コーデモデルのアイテム」では、コーデモデルのうち手持ちにある数を出す
private func statusText(_ r: OwnedFirstRecipe, _ actions: RenewalRecipeActions) -> String {
    if actions.visualMode == .exampleItems {
        let pieces = RenewalFlatLayBuilder.exampleItems(r, extraction: actions.extraction(r))
        if !pieces.isEmpty {
            let buy = pieces.filter { !$0.ownedMatch }.count
            return buy == 0 ? "手持ち\(pieces.count)点で完成" : "手持ち\(pieces.count - buy)点 ＋ 買い足す\(buy)点"
        }
    }
    return shortStatus(r)
}

/// 完成までの目盛り用 (手持ち数, 全体数)。見せ方「コーデモデルのアイテム」ではボードに並ぶ数に合わせる
private func completionCounts(_ r: OwnedFirstRecipe, _ actions: RenewalRecipeActions) -> (Int, Int) {
    if actions.visualMode == .exampleItems {
        let pieces = RenewalFlatLayBuilder.exampleItems(r, extraction: actions.extraction(r))
        if !pieces.isEmpty { return (pieces.filter(\.ownedMatch).count, pieces.count) }
    }
    return (r.owned_items.count, r.owned_items.count + r.missing_items.count)
}

private func shortStatus(_ r: OwnedFirstRecipe) -> String {
    if r.missing_items.isEmpty { return "手持ち\(r.owned_items.count)点で完成" }
    if r.owned_items.isEmpty { return "定番で組んだ案" }
    return "手持ち\(r.owned_items.count) ＋\(r.missing_items.count)点"
}

// MARK: - アイテムを並べたボード (フラットレイ)

struct RenewalFlatPiece: Identifiable, Hashable {
    enum Kind: Hashable { case owned, example, placeholder }

    let id: String
    let slot: String
    let imageURL: String?
    let label: String
    let kind: Kind
    /// コーデモデルのアイテムが手持ちにもある (見せ方「コーデモデルのアイテム」用)
    let ownedMatch: Bool
    /// 画像を生成中 (きらめかせる)。false の placeholder は画像が来ない「買い足す」枠
    var preparing: Bool = false
}

enum RenewalFlatLayBuilder {
    /// 手持ちを並べ、足りないスロットはコーデモデルから抽出したアイテムで埋める
    static func ownedPlusExample(_ r: OwnedFirstRecipe, extraction: OwnedFirstExtraction?) -> [RenewalFlatPiece] {
        var pieces = r.owned_items.map {
            RenewalFlatPiece(id: "o_\($0.item_id)", slot: $0.slot, imageURL: $0.image_url, label: $0.label, kind: .owned, ownedMatch: true)
        }
        var usedExample: Set<String> = []
        for m in r.missing_items {
            // 写真の切り抜き (背景つき) は並べると浮くので、商品風画像ができてから差し替える
            if let ex = extraction?.items.first(where: { $0.slot == m.slot && !usedExample.contains($0.id) && !$0.image_url.isEmpty }) {
                usedExample.insert(ex.id)
                pieces.append(RenewalFlatPiece(id: "e_\(ex.id)", slot: m.slot, imageURL: ex.image_url, label: ex.label, kind: .example, ownedMatch: false))
            } else {
                pieces.append(RenewalFlatPiece(id: "m_\(m.id)", slot: m.slot, imageURL: nil, label: m.label, kind: .placeholder,
                                               ownedMatch: false, preparing: extraction?.isInProgress ?? false))
            }
        }
        return pieces
    }

    /// コーデモデルが着ているアイテムを並べる。モデルの各アイテムを次の順で置き換える:
    ///  1. 案の手持ち (サーバがモデルと色・形の一致を確認済み) が同じスロットにある → 手持ちの写真
    ///  2. 案の「買い足す」が同じスロットにある → モデルのアイテム画像に「買い足す」
    ///  3. 抽出時に手持ちと一致した (インナーの白T など) → 手持ちの写真
    ///  4. それ以外 → 「買い足す」
    /// 抽出時の一致は色だけで判定しているため (青白ストライプ → 白シャツ 等)、1・2 を優先する。
    static func exampleItems(_ r: OwnedFirstRecipe, extraction: OwnedFirstExtraction?) -> [RenewalFlatPiece] {
        guard let items = extraction?.items, !items.isEmpty else { return [] }
        var usedOwned: Set<String> = []
        var usedMissing: Set<String> = []
        var pieces: [RenewalFlatPiece] = []
        let inProgress = extraction?.isInProgress ?? false
        func buy(_ it: OwnedFirstExtractedItem) -> RenewalFlatPiece {
            if !it.image_url.isEmpty {
                return RenewalFlatPiece(id: "x_\(it.id)", slot: it.slot, imageURL: it.image_url,
                                        label: it.label, kind: .example, ownedMatch: false)
            }
            // 商品画像を用意している間はきらめかせる。用意しない (1日の上限など) ときは写真の切り抜きで見せる
            if !inProgress, !it.crop_url.isEmpty {
                return RenewalFlatPiece(id: "x_\(it.id)", slot: it.slot, imageURL: it.crop_url,
                                        label: it.label, kind: .example, ownedMatch: false)
            }
            return RenewalFlatPiece(id: "x_\(it.id)", slot: it.slot, imageURL: nil, label: it.label,
                                    kind: .placeholder, ownedMatch: false, preparing: inProgress)
        }
        for it in items {
            if let o = r.owned_items.first(where: { $0.slot == it.slot && !usedOwned.contains($0.item_id) }) {
                usedOwned.insert(o.item_id)
                pieces.append(RenewalFlatPiece(id: "o_\(o.item_id)", slot: o.slot, imageURL: o.image_url, label: o.label, kind: .owned, ownedMatch: true))
            } else if let m = r.missing_items.first(where: { $0.slot == it.slot && !usedMissing.contains($0.id) }) {
                usedMissing.insert(m.id)
                pieces.append(buy(it))
            } else if let oid = it.owned_item_id, !usedOwned.contains(oid), let url = it.owned_image_url, !url.isEmpty {
                usedOwned.insert(oid)
                pieces.append(RenewalFlatPiece(id: "x_\(it.id)", slot: it.slot, imageURL: url, label: it.label, kind: .owned, ownedMatch: true))
            } else {
                pieces.append(buy(it))
            }
        }
        let slots = Set(pieces.map(\.slot))
        for o in r.owned_items where !usedOwned.contains(o.item_id) && !slots.contains(o.slot) {
            pieces.append(RenewalFlatPiece(id: "o_\(o.item_id)", slot: o.slot, imageURL: o.image_url, label: o.label, kind: .owned, ownedMatch: true))
        }
        return pieces
    }
}

/// アイテムを重ねて並べるボード (フラットレイ)。
/// 手持ち = 切り抜きをそのまま置く (クローゼット画像は透過 PNG)、持っていない = 点線の枠。
/// 配置: 羽織りあり = 羽織り (左上・最前面) / トップス (右上) / ボトムス (中央下) / 靴 (左下)
///       羽織りなし = トップス (左上・ボトムスの上に重ねる) / ボトムス (右下) / 靴 (左下)
struct RenewalFlatLayBoard: View {
    let pieces: [RenewalFlatPiece]
    var showsExampleTag = true
    var height: CGFloat = 200

    private var large: Bool { height >= 300 }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let tops = pieces.filter { $0.slot == "tops" }
            let outer = pieces.first { $0.slot == "outer" } ?? (tops.count > 1 ? tops[0] : nil)
            let top = tops.last { $0.id != outer?.id }
            let bottom = pieces.first { $0.slot == "bottoms" }
            let shoes = pieces.first { $0.slot == "shoes" }
            // 後に書いたものが手前
            ZStack(alignment: .topLeading) {
                if let outer {
                    if let top { piece(top).frame(width: w * 0.60, height: h * 0.48).position(x: w * 0.70, y: h * 0.26) }
                    if let bottom { piece(bottom).frame(width: w * 0.64, height: h * 0.60).position(x: w * 0.62, y: h * 0.69) }
                    piece(outer).frame(width: w * 0.70, height: h * 0.58).position(x: w * 0.35, y: h * 0.30)
                    if let shoes { piece(shoes).frame(width: w * 0.46, height: h * 0.27).position(x: w * 0.23, y: h * 0.85) }
                } else {
                    if let bottom { piece(bottom).frame(width: w * 0.72, height: h * 0.68).position(x: w * 0.63, y: h * 0.65) }
                    if let top { piece(top).frame(width: w * 0.84, height: h * 0.56).position(x: w * 0.42, y: h * 0.28) }
                    if let shoes { piece(shoes).frame(width: w * 0.48, height: h * 0.29).position(x: w * 0.24, y: h * 0.84) }
                }
            }
        }
        .frame(height: height)
        .background(RenewalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("並べたアイテム: " + pieces.map { "\($0.label)(\(isOwned($0) ? "手持ち" : "持っていない"))" }.joined(separator: "、"))
    }

    private func isOwned(_ p: RenewalFlatPiece) -> Bool { p.kind == .owned || p.ownedMatch }

    /// 手持ちは常に手前に出す (持っていないアイテムで手持ちが隠れないように)
    private func piece(_ p: RenewalFlatPiece) -> some View {
        // 入場時は「羽織り → トップス → ボトムス → 靴」の順に置く
        let order = ["outer": 0, "tops": 1, "bottoms": 2, "shoes": 3][p.slot] ?? 4
        let itemId = p.id.hasPrefix("o_") ? String(p.id.dropFirst(2)) : nil
        return pieceBody(p)
            .modifier(RenewalIntroPlace(order: order, itemId: itemId))
            .zIndex(isOwned(p) ? 1 : 0)
    }

    @ViewBuilder
    private func pieceBody(_ p: RenewalFlatPiece) -> some View {
        if isOwned(p), p.kind == .owned, let url = p.imageURL.flatMap(URL.init(string:)) {
            RenewalLiftedCutout(url: url, large: large)
        } else {
            notOwned(p)
        }
    }

    /// 持っていない (コーデモデルのアイテム / 未抽出) は、画像にぴったり沿った正方形のカード + 点線枠。
    /// 手持ち (切り抜き + 影) との違いが形でも分かるようにし、少し小さめに置く
    private func notOwned(_ p: RenewalFlatPiece) -> some View {
        let radius: CGFloat = large ? 12 : 8
        let matched = p.ownedMatch
        return ZStack {
            RenewalTokens.raised
            if let s = p.imageURL, let url = URL(string: s) {
                KFImage(url)
                    .placeholder { RenewalShimmer() }
                    .resizable()
                    .scaledToFill()
            } else {
                // 画像の準備中だけきらめかせる。画像が来ない枠は静かなシルエットのまま
                if p.preparing { RenewalShimmer() }
                Image(systemName: p.slot == "tops" ? "tshirt.fill" : (p.slot == "shoes" ? "shoe.fill" : "hanger"))
                    .font(.system(size: large ? 30 : 20))
                    .foregroundStyle(RenewalTokens.controlBorder)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(matched ? RenewalTokens.owned : RenewalTokens.muted.opacity(0.55),
                              style: StrokeStyle(lineWidth: matched ? 2 : 1.5, dash: matched ? [] : [5, 3]))
        )
        .overlay(alignment: .bottomLeading) { label(p) }
        .scaleEffect(matched ? 1 : 0.86)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    private func label(_ p: RenewalFlatPiece) -> some View {
        let owned = p.ownedMatch
        let text = owned ? "手持ちにあり" : "買い足す"
        return Text(text)
            .font(.system(size: large ? 11 : 10, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(owned ? .white : RenewalTokens.ink)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(owned ? RenewalTokens.owned : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
            .overlay(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius)
                .stroke(owned ? Color.clear : RenewalTokens.controlBorder, lineWidth: 1))
            .padding(4)
    }
}

/// 手持ちの切り抜き (透過 PNG)。特別な強調はせず、そのまま置く (持っていない物だけ点線で区別する)
struct RenewalLiftedCutout: View {
    let url: URL
    var large = false

    var body: some View {
        KFImage(url)
            .placeholder { RenewalTokens.raised.opacity(0.6).clipShape(RoundedRectangle(cornerRadius: 8)) }
            .resizable()
            .scaledToFit()
            .padding(2)
    }
}

/// 手持ち / 持っていない の凡例 (詳細シート用)
struct RenewalOwnedLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                Text("影つき = 手持ち")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(RenewalTokens.muted.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                    .frame(width: 14, height: 14)
                Text("点線 = 持っていない")
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(RenewalTokens.muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("影のついた服は手持ち、点線の枠は持っていないアイテム")
    }
}

/// カードに添える「コーデモデル」(このコーデの参考にした着こなし写真)。列幅いっぱいのバナーで見せる
struct RenewalCoordeModelChip: View {
    let example: OwnedFirstExample?
    var height: CGFloat = 76
    var onTap: () -> Void

    var body: some View {
        if let s = example?.image_url, let url = URL(string: s) {
            Button(action: onTap) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .overlay(alignment: .top) {
                        // 全身写真の上寄り (上半身) が見えるようにする
                        KFImage(url)
                            .placeholder { RenewalTokens.raised }
                            .resizable()
                            .scaledToFill()
                            .offset(y: -height * 0.25)
                    }
                    .clipped()
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 3) {
                            Text("コーデモデル")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("コーデモデルの着こなしを見る")
        }
    }
}

/// 見せ方に応じた案のビジュアル (写真 or 並べたアイテム)
struct RenewalRecipeVisual: View {
    let recipe: OwnedFirstRecipe
    let actions: RenewalRecipeActions
    var height: CGFloat

    var body: some View {
        let extraction = actions.extraction(recipe)
        switch actions.visualMode {
        case .photo:
            RenewalRemoteExampleImage(example: recipe.example, height: height, showBadge: false)
        case .ownedPlusExample:
            RenewalFlatLayBoard(pieces: RenewalFlatLayBuilder.ownedPlusExample(recipe, extraction: extraction), height: height)
                .overlay(alignment: .bottom) { progressBadge(extraction, needed: !recipe.missing_items.isEmpty) }
        case .exampleItems:
            let pieces = RenewalFlatLayBuilder.exampleItems(recipe, extraction: extraction)
            if pieces.isEmpty {
                // コーデモデルが無い / 抽出が終わっていない → 提案アイテム (手持ち＋買い足す枠) で並べる
                RenewalFlatLayBoard(pieces: RenewalFlatLayBuilder.ownedPlusExample(recipe, extraction: nil), height: height)
                    .overlay(alignment: .bottom) { progressBadge(extraction, needed: recipe.example != nil) }
            } else {
                RenewalFlatLayBoard(pieces: pieces, showsExampleTag: false, height: height)
                    .overlay(alignment: .bottom) { progressBadge(extraction, needed: true) }
            }
        }
    }

    @ViewBuilder
    private func progressBadge(_ e: OwnedFirstExtraction?, needed: Bool, fallback: String = "抽出中") -> some View {
        if needed, let e, e.isInProgress {
            RenewalPreparingBadge(text: "買い足すアイテムを用意中")
                .padding(6)
        }
    }
}

// MARK: - リスト (本命)

struct RenewalListLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions
    /// 入場演出の開始秒 (nil = 演出なし)
    var introDelay: Double? = nil

    private var isItemMode: Bool { actions.visualMode != .photo }
    /// アイテムを並べる見せ方では、カードを画面幅いっぱいに近づけてボードを大きくする
    private var edge: CGFloat { isItemMode ? 16 : RenewalTokens.edge }

    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                let start = introDelay.map { $0 + Double(index) * 0.08 }
                row(recipe, index: index)
                    .modifier(RenewalIntroRise(delay: start))
                    .environment(\.renewalIntroDelay, start.map { $0 + 0.15 })
            }
        }
        .padding(.horizontal, edge)
    }

    @ViewBuilder
    private func row(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        if isItemMode { itemRow(recipe, index: index) } else { photoRow(recipe, index: index) }
    }

    private func hasModel(_ r: OwnedFirstRecipe) -> Bool { (r.example?.image_url ?? "").isEmpty == false }

    /// 上: 見出し (左上・大きめ) / 左: アイテムのボード (カード幅の約58%) / 右: 状態・説明 (控えめ)・コーデモデル・決定
    private func itemRow(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(recipe.displayTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    if index == 0 { PickTag() }
                }
                RenewalPaletteRow(swatches: RenewalColorPalette.swatches(recipe))
            }
            HStack(alignment: .top, spacing: 10) {
                Button { actions.onDetail(recipe) } label: {
                    RenewalRecipeVisual(recipe: recipe, actions: actions, height: 184)
                        .containerRelativeFrame(.horizontal) { w, _ in (w - edge * 2 - 32) * 0.58 }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("案\(index + 1)。タップで詳細")

                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        let counts = completionCounts(recipe, actions)
                        RenewalCompletionSegments(owned: counts.0, total: counts.1)
                        Text(statusText(recipe, actions))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RenewalTokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    // コーデモデルが無い案は、その分の高さを説明に回す (空白を作らない)
                    Text(recipe.reason)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(RenewalTokens.muted)
                        .lineSpacing(2)
                        .lineLimit(hasModel(recipe) ? 2 : 6)
                        .fixedSize(horizontal: false, vertical: true)
                    if !hasModel(recipe) && recipe.missing_items.isEmpty {
                        Label("手持ちだけで組んだ案", systemImage: "hanger")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                    if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
                    if let w = recipe.climate_warnings?.first { ClimateWarningText(text: w).lineLimit(2) }
                    Spacer(minLength: 0)
                    RenewalCoordeModelChip(example: recipe.example, height: 76) { actions.onDetail(recipe) }
                    CompactDecideButton(recipe: recipe, actions: actions, fullWidth: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(RenewalTokens.border.opacity(0.7), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func photoRow(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRecipeVisual(recipe: recipe, actions: actions, height: 112)
                    .frame(width: 84)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("案\(index + 1)。タップで詳細")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if index == 0 { PickTag() }
                    Text(statusText(recipe, actions))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineLimit(1)
                }
                ItemStrip(recipe: recipe, size: 30)
                Text(recipe.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
                if let w = recipe.climate_warnings?.first { ClimateWarningText(text: w) }
                HStack(spacing: 0) {
                    Button("詳細") { actions.onDetail(recipe) }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                        .frame(minWidth: 44, minHeight: 44)
                    Spacer(minLength: 0)
                    CompactDecideButton(recipe: recipe, actions: actions)
                }
            }
        }
        .padding(10)
        .renewalCard()
    }
}

// MARK: - のぞき見カルーセル

struct RenewalPeekLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    card(recipe, index: index)
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.6 }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, RenewalTokens.edge, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private func card(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRecipeVisual(recipe: recipe, actions: actions, height: actions.visualMode == .photo ? 210 : 240)
            }
            .buttonStyle(.plain)
            HStack(spacing: 4) {
                if index == 0 { PickTag() }
                Text("\(index + 1)/\(recipes.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(RenewalTokens.muted)
            }
            Text(statusText(recipe, actions))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
            if actions.visualMode == .photo { ItemStrip(recipe: recipe, size: 32) }
            Text(recipe.reason)
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
            if let w = recipe.climate_warnings?.first { ClimateWarningText(text: w) }
            Spacer(minLength: 0)
            if actions.visualMode != .photo {
                RenewalCoordeModelChip(example: recipe.example) { actions.onDetail(recipe) }
            }
            CompactDecideButton(recipe: recipe, actions: actions, fullWidth: true)
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .renewalCard()
    }
}

// MARK: - 主役の服を選んで組む (アイテム軸)

/// ホーム上部の「主役の服を選んで組む」。クローゼットの服を横に並べ、
/// タップした服を主役に固定して3案を組み直す (api/home/owned-first?pivot_item_id=)。
struct RenewalPivotStrip: View {
    let items: [OwnedFirstItem]
    let pinnedId: String?
    let isLoading: Bool
    /// 選んだ服の id と、そのチップの画面上の位置 (主役の服が相棒へ飛ぶ演出用)
    let onSelect: (String?, CGRect?) -> Void
    @State private var chipFrames: [String: CGRect] = [:]

    private static let slotOrder = ["tops", "outer", "bottoms", "shoes"]

    private var sorted: [OwnedFirstItem] {
        items.sorted {
            (Self.slotOrder.firstIndex(of: $0.slot) ?? 9, $0.label) < (Self.slotOrder.firstIndex(of: $1.slot) ?? 9, $1.label)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("主役の服を選んで組む")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if pinnedId != nil {
                    Button("おまかせに戻す") {
                        Haptic.selection()
                        onSelect(nil, nil)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, RenewalTokens.edge)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    autoChip
                    ForEach(sorted) { item in itemChip(item) }
                }
                .padding(.top, 8)      // 固定中のピンがはみ出しても切れないように
                .padding(.bottom, 2)
            }
            .contentMargins(.horizontal, RenewalTokens.edge, for: .scrollContent)
        }
    }

    private var autoChip: some View {
        let on = pinnedId == nil
        return Button {
            guard !on else { return }
            Haptic.selection()
            onSelect(nil, nil)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(on ? RenewalTokens.primaryFill : RenewalTokens.surface)
                    VStack(spacing: 3) {
                        Image(systemName: "sparkles").font(.system(size: 18, weight: .semibold))
                        Text("相棒").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(on ? .white : RenewalTokens.ink)
                }
                .frame(width: 64, height: 64)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Color.clear : RenewalTokens.border, lineWidth: 1))
                Text("おまかせ")
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? RenewalTokens.ink : RenewalTokens.muted)
            }
            .frame(width: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("相棒のおまかせ")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func itemChip(_ item: OwnedFirstItem) -> some View {
        let on = pinnedId == item.item_id
        return Button {
            guard !on else { return }
            Haptic.selection()
            onSelect(item.item_id, chipFrames[item.item_id])
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(RenewalTokens.surface)
                    if let url = URL(string: item.image_url), !item.image_url.isEmpty {
                        KFImage(url)
                            .placeholder { RenewalShimmer().clipShape(RoundedRectangle(cornerRadius: 10)) }
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                    if on && isLoading {
                        RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.6))
                        ProgressView()
                    }
                }
                .frame(width: 64, height: 64)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { chipFrames[item.item_id] = $0 }
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(on ? RenewalTokens.ink : RenewalTokens.border, lineWidth: on ? 2 : 1))
                .overlay(alignment: .topTrailing) {
                    if on {
                        Image(systemName: "pin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, RenewalTokens.ink)
                            .offset(x: 5, y: -5)
                    }
                }
                // 「グレー パーカー」→「パーカー」(色は写真で分かるので、狭い幅では種類だけ)
                Text(item.label.split(separator: " ").last.map(String.init) ?? item.label)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? RenewalTokens.ink : RenewalTokens.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(on ? "\(item.label)を主役に固定中" : "\(item.label)を主役にして組む")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// 「買い足すアイテムを用意中」: ボード下部の白いカプセル (きらめくアイコン付き)
struct RenewalPreparingBadge: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RenewalTokens.accentPink)
                .opacity(pulse ? 1 : 0.35)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
        .onAppear {
            guard !reduceMotion else { pulse = true; return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// 読み込み中のきらめき (Reduce Motion では静止したグレー)
struct RenewalShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            RenewalTokens.raised
                .overlay {
                    if !reduceMotion {
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: phase * geo.size.width * 1.3)
                    }
                }
                .clipped()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
        }
        .accessibilityHidden(true)
    }
}
