//
//  BrandMatchShared.swift
//  irodori - Sandbox
//
//  ブランド 10 選の改善案で共用する部品。IRODORI のデザインシステム (taste-skill app-screens /
//  TasteTokens と同じ値) に沿う:
//  - 影なし。Ground (#F9FAFB) の上に白い面 + 1px の枠 (#E8E8E8) だけで階層を作る
//  - 複数の項目は 1 つの入れ物を 1px の罫線 (#EFEFEF) で区切る ("Group, don't box")
//  - 色はデータにだけ: あなたの位置・ど真ん中の印に 1 色 (#1D5FBF)。好きの印だけお気に入りのピンク
//  - 一覧の行は固定のロゴ枠 + 2 行 (名前 / 価格と合うところ)。理由の文や特徴は詳細シートへ
//

import SwiftUI

// MARK: - トークン (RenewalTokens = TasteTokens と同値。足りないものだけ足す)

enum BMTokens {
    static let ground = RenewalTokens.ground
    static let surface = RenewalTokens.surface
    static let raised = RenewalTokens.raised
    static let border = RenewalTokens.border
    static let rule = RenewalTokens.rule
    static let control = RenewalTokens.controlBorder
    static let ink = RenewalTokens.ink
    static let muted = RenewalTokens.muted
    /// #6B6B6B 補足の文字 (白地で 4.5:1)
    static let faint = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6B / 255)
    static let primary = RenewalTokens.primaryFill
    /// #1D5FBF 画面で唯一の色。データ (あなたの位置・ど真ん中) にだけ使う
    static let data = RenewalTokens.learned
    /// 「好き」の印 (お気に入りと同じピンク)
    static let favorite = RenewalTokens.accentPink

    static let cardRadius: CGFloat = 10
    static let controlRadius: CGFloat = 6
    static let chipRadius: CGFloat = 4
}

extension View {
    /// 白い面 + 1px の枠 (影なし)
    func bmCard(_ radius: CGFloat = BMTokens.cardRadius) -> some View {
        background(BMTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(BMTokens.border, lineWidth: 1))
    }
}

/// 1px の罫線 (行の区切り)
struct BMRule: View {
    var leading: CGFloat = 0
    var body: some View {
        Rectangle().fill(BMTokens.rule).frame(height: 1).padding(.leading, leading)
    }
}

// MARK: - ロゴ枠

/// 一覧で使う固定の画像枠。ロゴ・運営会社のロゴ・デザイナー・店舗の画像のどれか (札は付けない。
/// 何の画像かは詳細シートの「画像: …」で伝える)。どれも無いときだけ頭文字 (最終手段)
struct BMLogoTile: View {
    let brand: BMBrand
    var width: CGFloat = 64
    var height: CGFloat = 44

    var body: some View {
        ZStack {
            if let img = brand.image, let ui = img.uiImage {
                BMTokens.surface
                if img.kind.isPhoto {
                    // 写真は白黒に (一覧で写真だけが目立たないように)
                    Image(uiImage: ui).resizable().scaledToFill().grayscale(1)
                } else if img.dark {
                    // 白抜きのロゴは、黒で白い枠に置く (黒い枠は「選択中」に見えるため)
                    Image(uiImage: ui).renderingMode(.template).resizable().scaledToFit()
                        .foregroundStyle(BMTokens.ink).padding(height * 0.1)
                } else {
                    Image(uiImage: ui).resizable().scaledToFit()
                        .grayscale(img.kind == .brandLogo ? 0 : 1)   // 運営会社のロゴは白黒 (ブランドの色と混ざらないように)
                        .padding(height * 0.1)
                }
            } else {
                // どの画像も無いときだけ頭文字 (最終手段)
                BMTokens.surface
                Text(initial)
                    .font(.system(size: height * 0.4, weight: .semibold))
                    .foregroundStyle(BMTokens.faint)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous).stroke(BMTokens.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initial: String {
        brand.nameEn.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "・"
    }
}

// MARK: - 一覧の 1 行 (IRODORI の細身の行: 正方形のロゴ 52pt + 2 行。ピッチ 72pt)
//  1 行目: ブランド名 (+ 1 位は「イチオシ」)        ♡
//  2 行目: ✓ 合う理由 ・ ¥ の段階
//  カナ・テイスト・歴史は詳細シートへ

struct BMBrandRow: View {
    let pick: BMPick
    var rank: Int?
    var reaction: BMReaction?
    var showsChevron = true
    /// ♡ を押したとき (nil なら ♡ を出さない)
    var onLike: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(rank == 1 ? BMTokens.ink : BMTokens.faint)
                    .frame(width: 16)
                    .accessibilityLabel(Text("\(rank) 位"))
            }
            BMLogoTile(brand: pick.brand, width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                // 1 位だけ、名前の上にホームと同じ「イチオシ」(名前を押し出さない)
                if rank == 1 { DailyIchioshiBadge().fixedSize() }
                Text(pick.brand.nameEn)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BMTokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BMTokens.data)
                        Text(pick.reasonList)
                            .foregroundStyle(BMTokens.muted)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12))
                    Text("·").font(.system(size: 12)).foregroundStyle(BMTokens.control)
                    BMPriceScale(tier: pick.brand.tier, size: 11)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onLike {
                let liked = reaction == .like
                Button(action: onLike) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundStyle(liked ? BMTokens.favorite : BMTokens.faint)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(liked ? "好きを取り消す" : "好き"))
                .accessibilityAddTraits(liked ? .isSelected : [])
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BMTokens.faint)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)          // 52 + 20 = 72pt のピッチ
        .opacity(reaction == .notInterested ? 0.45 : 1)
    }
}

/// タイル表示の 1 マス (正方形のロゴ + 順位 + ♡ + 名前 + 価格)
struct BMBrandTile: View {
    let pick: BMPick
    let rank: Int
    var reaction: BMReaction?
    var onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { g in
                BMLogoTile(brand: pick.brand, width: g.size.width, height: g.size.width)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(BMTokens.surface)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(BMTokens.primary, in: RoundedRectangle(cornerRadius: BMTokens.chipRadius))
                    .padding(5)
            }
            .overlay(alignment: .topTrailing) {
                let liked = reaction == .like
                Button(action: onLike) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(liked ? BMTokens.favorite : BMTokens.faint)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(liked ? "好きを取り消す" : "好き"))
            }
            Text(pick.brand.nameEn)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BMTokens.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .topLeading)
            HStack(spacing: 4) {
                BMPriceScale(tier: pick.brand.tier)
                Text(pick.brand.styleTags.first ?? "").font(.system(size: 11)).foregroundStyle(BMTokens.muted).lineLimit(1)
            }
        }
        .opacity(reaction == .notInterested ? 0.45 : 1)
    }
}

/// 価格の段階: ¥ を 5 つ並べ、当てはまる数だけ濃く (言葉は省く。読み上げは「価格帯 5 段階中 3」)
struct BMPriceScale: View {
    let tier: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { i in
                Text("¥").foregroundStyle(i <= tier ? BMTokens.ink : BMTokens.control)
            }
        }
        .font(.system(size: size, weight: .semibold).monospacedDigit())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("価格帯 5 段階中 \(tier)"))
    }
}

/// 枠の名前 (色は付けず、灰色の小さな札)
struct BMSlotLabel: View {
    let slot: BMSlot
    var body: some View {
        Text(slot.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(BMTokens.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(BMTokens.raised, in: RoundedRectangle(cornerRadius: BMTokens.chipRadius, style: .continuous))
    }
}

/// セクションの見出し (16/600 + 件数 + 1 行の説明)
struct BMSectionHeader: View {
    let title: String
    var count: Int?
    var note: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(BMTokens.ink)
                if let count {
                    Text("\(count)").font(.system(size: 14).monospacedDigit()).foregroundStyle(BMTokens.muted)
                }
            }
            if let note {
                Text(note).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 相棒

/// 相棒のアイコン (サンプルユーザーのタイプの絵)
struct BMPartnerIcon: View {
    let persona: BMPersona
    var size: CGFloat = 36
    var body: some View {
        Group {
            if UIImage(named: persona.iconName) != nil {
                Image(persona.iconName).resizable().scaledToFill()
            } else {
                Image(systemName: "person.circle.fill").resizable().foregroundStyle(BMTokens.control)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(BMTokens.border, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// 相棒の吹き出し (フラット、1px の枠)
struct BMPartnerBubble: View {
    let persona: BMPersona
    let text: String
    var showsIcon = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if showsIcon { BMPartnerIcon(persona: persona, size: 32) } else { Color.clear.frame(width: 32, height: 1) }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(BMTokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BMTokens.surface, in: bubbleShape)
                .overlay(bubbleShape.stroke(BMTokens.border, lineWidth: 1))
            Spacer(minLength: 24)
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16,
                               topTrailingRadius: 16, style: .continuous)
    }
}

// MARK: - あなたとの距離 (4 軸)

struct BMAxisCompare: View {
    let user: [Double]
    let brand: [Double]

    private static let ends: [(String, String)] = [
        ("定番", "流行"), ("控えめ", "自分らしさ"), ("自由", "きちんと"), ("見た目", "着心地"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                legend("あなた", fill: BMTokens.data)
                HStack(spacing: 5) {
                    Circle().stroke(BMTokens.ink, lineWidth: 2).frame(width: 10, height: 10)
                    Text("ブランド").font(.system(size: 12)).foregroundStyle(BMTokens.muted)
                }
            }
            ForEach(0..<4, id: \.self) { i in
                VStack(spacing: 4) {
                    HStack {
                        Text(Self.ends[i].0)
                        Spacer()
                        Text(Self.ends[i].1)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(BMTokens.muted)
                    track(user: user[i], brand: brand[i])
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(Self.ends[i].0)から\(Self.ends[i].1)。あなた \(fmt(user[i]))、ブランド \(fmt(brand[i]))"))
            }
        }
    }

    private func legend(_ text: String, fill: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(fill).frame(width: 8, height: 8)
            Text(text).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
        }
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }

    private func track(user u: Double, brand b: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = { (v: Double) in CGFloat((v - 1) / 4) * (w - 10) + 5 }
            ZStack(alignment: .leading) {
                Rectangle().fill(Color(red: 0x9A / 255, green: 0xA0 / 255, blue: 0xA6 / 255)).frame(height: 2)   // 白地で 3:1
                Rectangle().fill(BMTokens.data.opacity(0.14))
                    .frame(width: abs(x(u) - x(b)), height: 6)
                    .offset(x: min(x(u), x(b)))
                // ブランド = 黒い輪、あなた = 青い点。同じ位置でも輪の中に点が見える
                Circle().stroke(BMTokens.ink, lineWidth: 2).background(Circle().fill(BMTokens.surface))
                    .frame(width: 16, height: 16).offset(x: x(b) - 8)
                Circle().fill(BMTokens.data).frame(width: 8, height: 8).offset(x: x(u) - 4)
            }
            .frame(height: 16)
        }
        .frame(height: 16)
    }
}

// MARK: - 反応ボタン (4 つ並び。選んだものだけ黒で塗る)

struct BMReactionBar: View {
    @Bindable var store: BMSandboxStore
    let brandID: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BMReaction.allCases) { r in
                let on = store.reaction(brandID) == r
                let fill = r == .like ? BMTokens.favorite : BMTokens.primary   // 「好き」はお気に入りのピンク
                Button { store.toggle(r, for: brandID) } label: {
                    Text(r.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(on ? BMTokens.surface : BMTokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? fill : BMTokens.surface,
                                    in: RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous)
                            .stroke(on ? .clear : BMTokens.control, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

// MARK: - 詳細シート

/// 並び: 合う理由 → どんな人向け → あなたとの距離 → ブランドのこと (歴史は畳む)。
/// 「興味なし / 好き / 公式サイト」は下に固定し、スクロールしなくても押せる
struct BMDetailSheet: View {
    @Bindable var store: BMSandboxStore
    let pick: BMPick
    @State private var showsHistory = false

    private var brand: BMBrand { pick.brand }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                // いちばん見てほしいところ: あなたとの相性 (一致度・相棒のひとこと・チャート・観点ごとの判定)
                group("あなたとの相性（IRODORI の見立て）") {
                    BMCompatibilityView(persona: store.persona, brand: brand)
                }

                group("相棒より: このブランドがあなたに合う理由", icon: true) {
                    ForEach(Array(pick.reasons.enumerated()), id: \.offset) { i, r in
                        if i > 0 { BMRule(leading: 16) }
                        Text(r)
                            .font(.system(size: 14))
                            .foregroundStyle(BMTokens.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }

                if let t = brand.targetPersona {
                    group("こんな人に合う（IRODORI の見立て）") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t).font(.system(size: 14)).foregroundStyle(BMTokens.ink).lineSpacing(4)
                            Text((brand.styleTags + brand.subTags).joined(separator: " · "))
                                .font(.system(size: 12))
                                .foregroundStyle(BMTokens.muted)
                        }
                        .padding(16)
                    }
                }

                group("ブランド情報") {
                    fact("価格帯", priceText)
                    BMRule(leading: 16)
                    fact("買える場所", brand.channels.isEmpty ? nil : brand.channels.joined(separator: "・"))
                    BMRule(leading: 16)
                    fact("創業", founded)
                    BMRule(leading: 16)
                    fact("運営", brand.company)
                    if let f = brand.features {
                        BMRule(leading: 16)
                        Text(f)
                            .font(.system(size: 14))
                            .foregroundStyle(BMTokens.ink)
                            .lineSpacing(4)
                            .padding(16)
                    }
                    if let h = brand.history {
                        BMRule(leading: 16)
                        DisclosureGroup(isExpanded: $showsHistory) {
                            Text(h)
                                .font(.system(size: 14))
                                .foregroundStyle(BMTokens.ink)
                                .lineSpacing(4)
                                .padding(.top, 8)
                        } label: {
                            Text("歴史").font(.system(size: 14, weight: .medium)).foregroundStyle(BMTokens.ink)
                        }
                        .tint(BMTokens.muted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                // 「持ってる」「知ってた」は控えめに (主な反応は下の固定ボタン)
                HStack(spacing: 8) {
                    Text("ほかに").font(.system(size: 12)).foregroundStyle(BMTokens.muted)
                    ForEach([BMReaction.owned, .known]) { r in
                        let on = store.reaction(brand.id) == r
                        Button { store.toggle(r, for: brand.id) } label: {
                            Text(r.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(on ? BMTokens.surface : BMTokens.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .background(on ? BMTokens.primary : BMTokens.surface,
                                            in: RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous)
                                    .stroke(on ? .clear : BMTokens.control, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let img = brand.image {
                        if let page = img.sourcePage, let url = URL(string: page) {
                            Link(destination: url) { Text(imageCredit(img)).underline() }
                        } else {
                            Text(imageCredit(img))
                        }
                    }
                    Text("創業・運営・価格帯は 2026 年 10 月の調査値。IRODORI とブランドの提携はありません。")
                }
                .font(.system(size: 12))
                .foregroundStyle(BMTokens.faint)
            }
            .padding(20)
        }
        .background(BMTokens.ground)
        .safeAreaInset(edge: .bottom) { actionBar }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            BMSlotLabel(slot: pick.slot)
            HStack(spacing: 14) {
                BMLogoTile(brand: brand, width: 88, height: 88)
                VStack(alignment: .leading, spacing: 3) {
                    Text(brand.nameEn)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(BMTokens.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(brand.nameJa).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
                    if let img = brand.image, img.kind != .brandLogo {
                        Text("画像: " + img.label).font(.system(size: 11)).foregroundStyle(BMTokens.faint).lineLimit(2)
                    }
                }
            }
        }
    }

    /// 下に固定: 興味なし / 好き (お気に入りのピンク) / 公式サイト
    private var actionBar: some View {
        VStack(spacing: 0) {
            BMRule()
            HStack(spacing: 8) {
                let ng = store.reaction(brand.id) == .notInterested
                let like = store.reaction(brand.id) == .like
                Button { store.toggle(.notInterested, for: brand.id) } label: {
                    Label("興味なし", systemImage: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ng ? BMTokens.surface : BMTokens.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(ng ? BMTokens.primary : BMTokens.surface,
                                    in: RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(ng ? .clear : BMTokens.control, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(ng ? .isSelected : [])
                Button { store.toggle(.like, for: brand.id) } label: {
                    Label("好き", systemImage: like ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(like ? BMTokens.surface : BMTokens.favorite)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(like ? BMTokens.favorite : BMTokens.surface,
                                    in: RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(like ? .clear : BMTokens.control, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(like ? .isSelected : [])
                if let s = brand.officialURL, let url = URL(string: s) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("公式サイト")
                            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BMTokens.surface)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(BMTokens.primary, in: RoundedRectangle(cornerRadius: BMTokens.controlRadius, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(BMTokens.surface)
    }

    /// 例: 画像: 運営会社のロゴ（オンワード樫山）・出典: 公式サイト / 画像: ロゴ・出典: Wikimedia Commons（Public domain）
    private func imageCredit(_ img: BMImage) -> String {
        var s = "画像: " + img.label
        if let src = img.source {
            s += "・出典: " + src
            if let l = img.license, !l.isEmpty { s += "（" + l + "）" }
        }
        return s
    }

    private var founded: String? {
        // 括弧の補足は省く (語の途中で折れて読みにくいため。全文は歴史に)
        let f = brand.founder.map { String($0.split(separator: "（").first ?? Substring($0)).trimmingCharacters(in: .whitespaces) }
        guard let y = brand.foundedYear else { return f }
        if let f, !f.isEmpty { return "\(y) 年・" + f }
        return "\(y) 年"
    }

    private var priceText: String {
        var s = brand.yen + " " + brand.tierLabel
        if let r = brand.priceRange { s += "\n" + r.replacingOccurrences(of: " / ", with: "\n") }
        return s
    }

    private func group<C: View>(_ title: String, icon: Bool = false, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if icon { BMPartnerIcon(persona: store.persona, size: 24) }
                Text(title).font(.system(size: 12)).foregroundStyle(BMTokens.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .bmCard()
        }
    }

    private func fact(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(BMTokens.muted)
                .frame(width: 68, alignment: .leading)
            Text(value ?? "—")
                .font(.system(size: 14).monospacedDigit())
                .foregroundStyle(value == nil ? BMTokens.faint : BMTokens.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
