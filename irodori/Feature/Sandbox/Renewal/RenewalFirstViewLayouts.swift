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
    static let storageKey = "renewalSandbox.visualMode"

    var label: String {
        switch self {
        case .photo: return "写真"
        case .ownedPlusExample: return "手持ち＋コーデモデル"
        case .exampleItems: return "コーデモデルのアイテム"
        }
    }

    var summary: String {
        switch self {
        case .photo: return "コーデモデル (Pinterest) の写真で雰囲気を見せる"
        case .ownedPlusExample: return "手持ちの服を並べ、足りない分だけコーデモデルのアイテムで埋める"
        case .exampleItems: return "コーデモデルのアイテムを並べ、手持ちにあるものを緑の枠で示す"
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

// MARK: - 切替バー (Sandbox 用)

struct RenewalViewModeSwitcher: View {
    @Binding var layoutRaw: String
    @Binding var visualRaw: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chipRow(title: "レイアウト", options: RenewalFirstViewLayout.allCases.map { ($0.rawValue, $0.label) }, selection: $layoutRaw)
            chipRow(title: "見せ方", options: RenewalVisualMode.allCases.map { ($0.rawValue, $0.label) }, selection: $visualRaw)
            Text((RenewalVisualMode(rawValue: visualRaw) ?? .photo).summary)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
                .padding(.horizontal, RenewalTokens.edge)
        }
    }

    private func chipRow(title: String, options: [(String, String)], selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(width: 56, alignment: .leading)
                ForEach(options, id: \.0) { value, label in
                    let on = value == selection.wrappedValue
                    Button {
                        Haptic.selection()
                        selection.wrappedValue = value
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? .white : RenewalTokens.ink)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(on ? RenewalTokens.primaryFill : RenewalTokens.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : RenewalTokens.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, RenewalTokens.edge)
        }
    }
}

// MARK: - 気候の目安 (日付バーの下)

struct RenewalClimateRow: View {
    let climate: OwnedFirstClimate

    var body: some View {
        HStack(spacing: 8) {
            Text(climate.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius).stroke(RenewalTokens.controlBorder, lineWidth: 1))
            Text(climate.guidance)
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RenewalTokens.edge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(climate.label)。服装の目安: \(climate.guidance)")
    }
}

// MARK: - 共通の小部品

private struct DiscoveryTag: View {
    var body: some View {
        Text("発見枠")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(RenewalTokens.discovery)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RenewalTokens.discovery.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
    }
}

private struct PickTag: View {
    var body: some View {
        Text("イチオシ")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RenewalTokens.primaryFill)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.chipRadius))
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
    if actions.visualMode == .exampleItems, let e = actions.extraction(r), !e.items.isEmpty {
        let owned = e.items.filter { $0.owned_item_id != nil }.count
        return "モデルのうち手持ち\(owned)/\(e.items.count)点"
    }
    return shortStatus(r)
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
}

enum RenewalFlatLayBuilder {
    /// 手持ちを並べ、足りないスロットはコーデモデルから抽出したアイテムで埋める
    static func ownedPlusExample(_ r: OwnedFirstRecipe, extraction: OwnedFirstExtraction?) -> [RenewalFlatPiece] {
        var pieces = r.owned_items.map {
            RenewalFlatPiece(id: "o_\($0.item_id)", slot: $0.slot, imageURL: $0.image_url, label: $0.label, kind: .owned, ownedMatch: true)
        }
        var usedExample: Set<String> = []
        for m in r.missing_items {
            if let ex = extraction?.items.first(where: { $0.slot == m.slot && !usedExample.contains($0.id) && !$0.displayURL.isEmpty }) {
                usedExample.insert(ex.id)
                pieces.append(RenewalFlatPiece(id: "e_\(ex.id)", slot: m.slot, imageURL: ex.displayURL, label: ex.label, kind: .example, ownedMatch: false))
            } else {
                pieces.append(RenewalFlatPiece(id: "m_\(m.id)", slot: m.slot, imageURL: nil, label: m.label, kind: .placeholder, ownedMatch: false))
            }
        }
        return pieces
    }

    /// コーデモデルのアイテムをそのまま並べる
    static func exampleItems(_ extraction: OwnedFirstExtraction?) -> [RenewalFlatPiece] {
        (extraction?.items ?? []).filter { !$0.displayURL.isEmpty }.map {
            RenewalFlatPiece(id: "x_\($0.id)", slot: $0.slot, imageURL: $0.displayURL, label: $0.label,
                             kind: .example, ownedMatch: $0.owned_item_id != nil)
        }
    }
}

/// アイテムを重ねて並べるボード (フラットレイ)。
/// 手持ち = 服のシルエットに沿った緑の縁取り (クローゼット画像は透過 PNG)、持っていない = 点線の枠。
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
        pieceBody(p).zIndex(isOwned(p) ? 1 : 0)
    }

    @ViewBuilder
    private func pieceBody(_ p: RenewalFlatPiece) -> some View {
        if isOwned(p), p.kind == .owned, let url = p.imageURL.flatMap(URL.init(string:)) {
            // 透過 PNG のシルエットに沿って縁取る (影を4方向にずらして重ねる)
            let c = RenewalTokens.owned
            let d: CGFloat = large ? 2.2 : 1.6
            KFImage(url)
                .placeholder { ProgressView() }
                .resizable()
                .scaledToFit()
                .compositingGroup()
                .shadow(color: c, radius: 0, x: d, y: 0)
                .shadow(color: c, radius: 0, x: -d, y: 0)
                .shadow(color: c, radius: 0, x: 0, y: d)
                .shadow(color: c, radius: 0, x: 0, y: -d)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                .padding(d)
        } else {
            notOwned(p)
        }
    }

    /// 持っていない (コーデモデルのアイテム / 未抽出) は、画像にぴったり沿った正方形のカード + 点線枠。
    /// 手持ち (切り抜き + 緑の縁) との違いが形でも分かるようにし、少し小さめに置く
    private func notOwned(_ p: RenewalFlatPiece) -> some View {
        let radius: CGFloat = large ? 12 : 8
        let matched = p.ownedMatch
        return ZStack {
            RenewalTokens.raised
            if let s = p.imageURL, let url = URL(string: s) {
                KFImage(url)
                    .placeholder { ProgressView() }
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 3) {
                    Image(systemName: p.slot == "tops" ? "tshirt" : (p.slot == "shoes" ? "shoe" : "hanger"))
                        .font(.system(size: large ? 24 : 16))
                    Text(p.label)
                        .font(.system(size: large ? 12 : 10, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(RenewalTokens.muted)
                .padding(4)
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
        let text = owned ? "手持ちにあり" : (p.kind == .example && showsExampleTag ? "コーデモデル" : "持っていない")
        return Text(text)
            .font(.system(size: large ? 11 : 10, weight: .semibold))
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

/// 手持ち / 持っていない の凡例 (アイテムを並べる見せ方の一覧の上)
struct RenewalOwnedLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.surface)
                    .shadow(color: RenewalTokens.owned, radius: 0, x: 1.2, y: 0)
                    .shadow(color: RenewalTokens.owned, radius: 0, x: -1.2, y: 0)
                    .shadow(color: RenewalTokens.owned, radius: 0, x: 0, y: 1.2)
                    .shadow(color: RenewalTokens.owned, radius: 0, x: 0, y: -1.2)
                Text("緑の縁 = 手持ち")
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
        .accessibilityLabel("緑の縁取りは手持ち、点線の枠は持っていないアイテム")
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
                .overlay(alignment: .topLeading) { progressBadge(extraction, needed: !recipe.missing_items.isEmpty) }
        case .exampleItems:
            let pieces = RenewalFlatLayBuilder.exampleItems(extraction)
            if pieces.isEmpty {
                // 抽出が終わるまでは写真を出さず、手持ち＋不足アイテムで仮に並べておく
                RenewalFlatLayBoard(pieces: RenewalFlatLayBuilder.ownedPlusExample(recipe, extraction: nil), height: height)
                    .overlay(alignment: .topLeading) { progressBadge(extraction, needed: true, fallback: "コーデモデルからアイテムを抽出中") }
            } else {
                RenewalFlatLayBoard(pieces: pieces, showsExampleTag: false, height: height)
                    .overlay(alignment: .topLeading) { progressBadge(extraction, needed: true) }
            }
        }
    }

    @ViewBuilder
    private func progressBadge(_ e: OwnedFirstExtraction?, needed: Bool, fallback: String = "抽出中") -> some View {
        if needed, let e, e.isInProgress {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(e.status == "cropped" ? "商品画像を生成中" : fallback)
                    .font(.system(size: 9, weight: .semibold))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(4)
        }
    }
}

// MARK: - リスト (本命)

struct RenewalListLayout: View {
    let recipes: [OwnedFirstRecipe]
    let actions: RenewalRecipeActions

    private var isItemMode: Bool { actions.visualMode != .photo }
    /// アイテムを並べる見せ方では、カードを画面幅いっぱいに近づけてボードを大きくする
    private var edge: CGFloat { isItemMode ? 16 : RenewalTokens.edge }

    var body: some View {
        VStack(spacing: 10) {
            if isItemMode { RenewalOwnedLegend().padding(.horizontal, 4) }
            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                row(recipe, index: index)
            }
            Button(action: actions.onPivot) {
                Text("使う服を変える")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, edge)
    }

    @ViewBuilder
    private func row(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        if isItemMode { itemRow(recipe, index: index) } else { photoRow(recipe, index: index) }
    }

    /// 左: アイテムのボード (カード幅の約57%) / 右: 理由・コーデモデル・決定
    private func itemRow(_ recipe: OwnedFirstRecipe, index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { actions.onDetail(recipe) } label: {
                RenewalRecipeVisual(recipe: recipe, actions: actions, height: 248)
                    .containerRelativeFrame(.horizontal) { w, _ in (w - edge * 2 - 20) * 0.58 }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("案\(index + 1)。タップで詳細")

            VStack(alignment: .leading, spacing: 6) {
                if index == 0 || recipe.isDiscovery {
                    HStack(spacing: 4) {
                        if index == 0 { PickTag() }
                        if recipe.isDiscovery { DiscoveryTag() }
                    }
                }
                Text(statusText(recipe, actions))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(recipe.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(1)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if actions.showCharCount { RenewalCharCountBadge(text: recipe.reason) }
                if let w = recipe.climate_warnings?.first { ClimateWarningText(text: w).lineLimit(2) }
                Spacer(minLength: 0)
                RenewalCoordeModelChip(example: recipe.example) { actions.onDetail(recipe) }
                CompactDecideButton(recipe: recipe, actions: actions, fullWidth: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .renewalCard()
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
                    if recipe.isDiscovery { DiscoveryTag() }
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
                if recipe.isDiscovery { DiscoveryTag() }
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
