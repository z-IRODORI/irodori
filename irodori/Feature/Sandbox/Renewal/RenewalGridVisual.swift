//
//  RenewalGridVisual.swift
//  irodori
//
//  ホームの2列のカードの「コーデの画像」。写真の有無で中身だけを変え、枠・大きさ・部品の位置はそろえる。
//    写真あり: コーデモデルの写真を全面に。下の帯は暗くして、見出しを白で重ねる
//    写真なし: 服を 2×2 のタイルに並べる (足りないマスは色の組み合わせの見本)。下の帯は淡い色で、見出しは濃い文字
//  下の帯 (見出しと服の数) の位置と高さは、どちらも同じ。
//

import SwiftUI
import Kingfisher

struct RenewalGridVisual: View {
    let recipe: OwnedFirstRecipe
    let actions: RenewalRecipeActions
    var height: CGFloat
    /// 写真があっても使わない (DEBUG の見た目の確認用)
    var hidePhoto = false

    /// 下の帯 (使う服・服の数・見出し) の高さ
    static let bandHeight: CGFloat = 64

    private var pieces: [RenewalFlatPiece] {
        let order = ["outer": 0, "tops": 1, "bottoms": 2, "shoes": 3]
        return RenewalFlatLayBuilder.boardPieces(recipe, extraction: actions.extraction(recipe), mode: actions.visualMode)
            .sorted { (order[$0.slot] ?? 9) < (order[$1.slot] ?? 9) }
    }

    private var photoURL: URL? {
        guard !hidePhoto, let s = recipe.example?.image_url, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var body: some View {
        let hasPhoto = photoURL != nil
        ZStack(alignment: .bottomLeading) {
            if let photoURL { photo(photoURL) } else { tiles }
            band(onPhoto: hasPhoto)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: 写真あり

    private func photo(_ url: URL) -> some View {
        KFImage(url)
            .placeholder { RenewalTokens.raised }
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.bandHeight + 36)
                    .allowsHitTesting(false)
            }
    }

    // MARK: 写真なし (2×2 のタイル)

    private var tiles: some View {
        let ps = Array(pieces.prefix(4))
        let gap: CGFloat = 4
        return GeometryReader { geo in
            let cellW = (geo.size.width - gap * 3) / 2
            let cellH = (geo.size.height - Self.bandHeight - gap * 3) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    cell(ps.indices.contains(0) ? ps[0] : nil, w: cellW, h: cellH)
                    cell(ps.indices.contains(1) ? ps[1] : nil, w: cellW, h: cellH)
                }
                HStack(spacing: gap) {
                    cell(ps.indices.contains(2) ? ps[2] : nil, w: cellW, h: cellH)
                    if ps.count >= 4 { cell(ps[3], w: cellW, h: cellH) } else { paletteCell(w: cellW, h: cellH) }
                }
                Spacer(minLength: 0)
            }
            .padding(gap)
        }
        .frame(height: height)
        .background(tint)
    }

    @ViewBuilder
    private func cell(_ p: RenewalFlatPiece?, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color.white
            if let p { cutout(p).padding(6) }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    /// 足りないマスは、そのコーデの色の組み合わせの見本
    private func paletteCell(w: CGFloat, h: CGFloat) -> some View {
        let swatches = RenewalColorPalette.swatches(recipe)
        return VStack(spacing: 6) {
            HStack(spacing: -5) {
                ForEach(swatches, id: \.name) { sw in
                    Circle().fill(sw.color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .overlay(Circle().stroke(RenewalTokens.border, lineWidth: 0.5).padding(-0.75))
                }
            }
            Text(swatches.map(\.name).joined(separator: "×"))
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(6)
        .frame(width: w, height: h)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityHidden(swatches.isEmpty)
    }

    // MARK: 下の帯 (どちらも同じ位置・高さ)

    private func band(onPhoto: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if onPhoto {
                    // 写真の服が何かは、写真だけでは分からないので小さく添える
                    HStack(spacing: -6) {
                        ForEach(pieces.prefix(3)) { p in
                            cutout(p)
                                .padding(3)
                                .frame(width: 24, height: 24)
                                .background(.white, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 1.2))
                        }
                    }
                }
                if let status = statusText {
                    Text(status)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(onPhoto ? RenewalTokens.ink : .white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(onPhoto ? Color.white.opacity(0.92) : RenewalTokens.primaryFill, in: Capsule())
                }
            }
            .frame(height: 24, alignment: .leading)
            Text(recipe.displayTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(onPhoto ? .white : RenewalTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: onPhoto ? .black.opacity(0.3) : .clear, radius: 2, y: 1)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .frame(height: Self.bandHeight, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 「手持ちで完成」「あと1点」。手持ちの服を使っていない案 (定番だけで組んだ案) は出さない
    private var statusText: String? {
        guard !recipe.owned_items.isEmpty else { return nil }
        let missing: Int
        if actions.visualMode == .exampleItems {
            let ex = RenewalFlatLayBuilder.exampleItems(recipe, extraction: actions.extraction(recipe))
            missing = ex.isEmpty ? recipe.missing_items.count : ex.filter { !$0.ownedMatch }.count
        } else {
            missing = recipe.missing_items.count
        }
        return missing == 0 ? "手持ちで完成" : "あと\(missing)点"
    }

    // MARK: 部品

    /// 服の画像だけ (枠・札なし)。画像が無いときは薄いシルエット
    @ViewBuilder
    private func cutout(_ p: RenewalFlatPiece) -> some View {
        if let s = p.imageURL, let url = URL(string: s) {
            KFImage(url)
                .placeholder { RenewalShimmer().clipShape(RoundedRectangle(cornerRadius: 6)) }
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: p.slot == "tops" || p.slot == "outer" ? "tshirt.fill" : (p.slot == "shoes" ? "shoe.fill" : "hanger"))
                .resizable()
                .scaledToFit()
                .padding(8)
                .foregroundStyle(RenewalTokens.controlBorder)
        }
    }

    /// 写真なしの背景は、コーデの色の系統にうっすら寄せる
    private var tint: Color {
        switch recipe.main_family {
        case "earth": return Color(red: 0.96, green: 0.93, blue: 0.89)
        case "blue": return Color(red: 0.92, green: 0.95, blue: 0.98)
        case "accent": return Color(red: 0.98, green: 0.93, blue: 0.93)
        default: return Color(red: 0.94, green: 0.94, blue: 0.95)
        }
    }
}
