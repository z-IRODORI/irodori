//
//  RenewalGridVisual.swift
//  irodori
//
//  ホームの2列のカードに出す「コーデの画像」の見せ方 (くらべて決めるため、DEBUG では切り替えられる)。
//    board : これまでの服のボード (重ねて並べる・点線の枠)
//    stack : 服を上から トップス → ボトムス → 靴 の順に、枠なしで縦に並べる (着たときの並び)
//    photo : コーデモデルの写真を大きく、下に手持ちの服を小さく並べる
//    split : 左にコーデモデルの写真、右に服を縦に3つ
//

import SwiftUI
import Kingfisher

enum RenewalGridVisualStyle: String, CaseIterable, Identifiable {
    case cover, stack, photo, split, board

    var id: String { rawValue }
    static let storageKey = "debug.gridVisual"

    var label: String {
        switch self {
        case .cover: return "写真に見出しを重ねる"
        case .stack: return "縦に並べる"
        case .photo: return "写真を大きく"
        case .split: return "写真と服を半分ずつ"
        case .board: return "これまでのボード"
        }
    }
}

struct RenewalGridVisual: View {
    let recipe: OwnedFirstRecipe
    let actions: RenewalRecipeActions
    let style: RenewalGridVisualStyle
    var height: CGFloat

    private var pieces: [RenewalFlatPiece] {
        RenewalFlatLayBuilder.boardPieces(recipe, extraction: actions.extraction(recipe), mode: actions.visualMode)
    }

    private var photoURL: String? {
        guard let s = recipe.example?.image_url, !s.isEmpty else { return nil }
        return s
    }

    var body: some View {
        switch style {
        case .board:
            RenewalRecipeVisual(recipe: recipe, actions: actions, height: height)
                .environment(\.renewalCompactBoard, true)
        case .stack:
            stackView
        case .photo:
            if let photoURL { photoView(photoURL) } else { stackView }
        case .cover:
            if let photoURL { coverView(photoURL) } else { stackView }
        case .split:
            if let photoURL { splitView(photoURL) } else { stackView }
        }
    }

    // MARK: 縦に並べる

    /// 服を着たときの順 (羽織り・トップス → ボトムス) で縦に重ね、靴は右下に小さく。枠や札は付けない
    private var stackView: some View {
        let ps = pieces
        let upper = ps.first { $0.slot == "outer" } ?? ps.first { $0.slot == "tops" }
        let inner = ps.first { $0.slot == "outer" } != nil ? ps.first { $0.slot == "tops" } : nil
        let lower = ps.first { $0.slot == "bottoms" }
        let shoes = ps.first { $0.slot == "shoes" }
        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if let lower { cutout(lower).frame(width: w * 0.62, height: h * 0.58).position(x: w * 0.5, y: h * 0.68) }
                if let inner { cutout(inner).frame(width: w * 0.44, height: h * 0.40).position(x: w * 0.68, y: h * 0.26) }
                if let upper { cutout(upper).frame(width: w * (inner == nil ? 0.66 : 0.56), height: h * 0.46).position(x: w * (inner == nil ? 0.5 : 0.40), y: h * 0.27) }
                if let shoes { cutout(shoes).frame(width: w * 0.30, height: h * 0.20).position(x: w * 0.80, y: h * 0.86) }
            }
        }
        .frame(height: height)
        .background(tint)
    }

    // MARK: 写真を大きく

    private func photoView(_ url: String) -> some View {
        KFImage(URL(string: url))
            .placeholder { RenewalTokens.raised }
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                // 手持ちの服 (または一緒に使う服) を小さく並べる
                HStack(spacing: -6) {
                    ForEach(pieces.prefix(3)) { p in
                        cutout(p)
                            .padding(3)
                            .frame(width: 34, height: 34)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                }
                .padding(6)
            }
    }

    // MARK: 写真に見出しを重ねる

    /// 写真を縦に大きく。下を暗くして見出しを白で重ね、その上に使う服を小さく並べる
    private func coverView(_ url: String) -> some View {
        KFImage(URL(string: url))
            .placeholder { RenewalTokens.raised }
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: height, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: height * 0.45)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: -6) {
                        ForEach(orderedPieces.prefix(3)) { p in
                            cutout(p)
                                .padding(3)
                                .frame(width: 30, height: 30)
                                .background(.white, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                    Text(recipe.displayTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
                .padding(8)
            }
    }

    // MARK: 写真と服を半分ずつ

    private func splitView(_ url: String) -> some View {
        HStack(spacing: 4) {
            KFImage(URL(string: url))
                .placeholder { RenewalTokens.raised }
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: height, alignment: .top)
                .clipped()
            VStack(spacing: 4) {
                ForEach(orderedPieces.prefix(3)) { p in
                    cutout(p)
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(tint)
                }
            }
            .frame(width: 58)
        }
        .frame(height: height)
    }

    // MARK: 部品

    /// 羽織り・トップス → ボトムス → 靴 の順
    private var orderedPieces: [RenewalFlatPiece] {
        let order = ["outer": 0, "tops": 1, "bottoms": 2, "shoes": 3]
        return pieces.sorted { (order[$0.slot] ?? 9) < (order[$1.slot] ?? 9) }
    }

    /// 服の画像だけ (枠・札なし)。画像が無いときは薄いシルエット
    @ViewBuilder
    private func cutout(_ p: RenewalFlatPiece) -> some View {
        if let s = p.imageURL, let url = URL(string: s) {
            KFImage(url)
                .placeholder { RenewalShimmer().clipShape(RoundedRectangle(cornerRadius: 8)) }
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: p.slot == "tops" || p.slot == "outer" ? "tshirt.fill" : (p.slot == "shoes" ? "shoe.fill" : "hanger"))
                .resizable()
                .scaledToFit()
                .padding(10)
                .foregroundStyle(RenewalTokens.controlBorder)
        }
    }

    /// 背景はコーデの色の系統にうっすら寄せる
    private var tint: Color {
        switch recipe.main_family {
        case "earth": return Color(red: 0.97, green: 0.95, blue: 0.92)
        case "blue": return Color(red: 0.94, green: 0.96, blue: 0.98)
        case "accent": return Color(red: 0.98, green: 0.95, blue: 0.95)
        default: return Color(red: 0.96, green: 0.96, blue: 0.96)
        }
    }
}
