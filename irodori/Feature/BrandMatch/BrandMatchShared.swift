//
//  BrandMatchShared.swift
//  irodori
//
//  ブランド 10 選の改善案で共用する部品。IRODORI のデザインシステム (taste-skill app-screens /
//  TasteTokens と同じ値) に沿う:
//  - 影なし。Ground (#F9FAFB) の上に白い面 + 1px の枠 (#E8E8E8) だけで階層を作る
//  - 複数の項目は 1 つの入れ物を 1px の罫線 (#EFEFEF) で区切る ("Group, don't box")
//  - 色は使わず白・黒・グレーで組む。好きの印だけお気に入りのピンク
//  - 一覧の行は固定のロゴ枠 + 2 行 (名前 / 価格と合うところ)。理由の文や特徴は詳細シートへ
//

import SwiftUI
import Kingfisher

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

/// 一覧で使う固定の画像枠。ロゴ・運営会社のロゴ・デザイナー・店舗の画像のどれか (札は付けない)。
/// どれも無いときだけ頭文字 (最終手段)
struct BMLogoTile: View {
    let brand: BMBrand
    var width: CGFloat = 64
    var height: CGFloat = 44

    @State private var failed = false

    var body: some View {
        ZStack {
            BMTokens.surface
            if let img = brand.image, let ui = img.uiImage {
                styled(Image(uiImage: ui), img)            // 改善案: アプリに入れた画像
            } else if let img = brand.image, let url = img.url, !failed {
                remote(url, img)                           // 本番: API が配る画像
            } else {
                // どの画像も無いときだけ頭文字 (最終手段)
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

    /// 写真は白黒で枠いっぱい / 白抜きのロゴは黒で / 運営会社のロゴは白黒 (ブランドの色と混ざらないように)
    @ViewBuilder
    private func styled(_ image: Image, _ img: BMImage) -> some View {
        if img.kind.isPhoto {
            image.resizable().scaledToFill().grayscale(1)
        } else if img.dark {
            image.renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(BMTokens.ink).padding(height * 0.1)
        } else {
            image.resizable().scaledToFit()
                .grayscale(img.kind == .brandLogo ? 0 : 1)
                .padding(height * 0.1)
        }
    }

    @ViewBuilder
    private func remote(_ url: URL, _ img: BMImage) -> some View {
        if img.kind.isPhoto {
            KFImage(url).onFailure { _ in failed = true }
                .resizable().scaledToFill().grayscale(1)
        } else if img.dark {
            KFImage(url).onFailure { _ in failed = true }
                .renderingMode(.template).resizable().scaledToFit()
                .foregroundStyle(BMTokens.ink).padding(height * 0.1)
        } else {
            KFImage(url).onFailure { _ in failed = true }
                .resizable().scaledToFit()
                .grayscale(img.kind == .brandLogo ? 0 : 1)
                .padding(height * 0.1)
        }
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
                            .foregroundStyle(BMTokens.ink)
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

/// 価格の段階: 詳細と同じ 5 段階のメーター (当てはまる段階まで黒で埋める)。
/// ¥ の数より度合いが一目でわかる。読み上げは「価格帯 5 段階中 3、ミドル」
struct BMPriceScale: View {
    let tier: Int
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(i <= tier ? BMTokens.ink : BMTokens.border)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("価格帯 5 段階中 \(tier)、\(BMBrand.tierLabels[max(0, min(5, tier))])"))
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
    @Bindable var store: BrandMatchStore
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

/// 並び: ブランド名 → 価格帯 (手に入るかを最初に) → 好みの一致度とチャート (相棒のひとこと) →
/// 相棒より: 合う理由 (#好み #価格 #テイスト) → こんな人に合う → ブランド情報 (歴史は畳む) → 注意事項。
/// 色は使わず白・黒・グレーで組む (好きのピンクだけ例外)。「興味なし / 好き / 公式サイト」は下に固定
struct BMDetailSheet: View {
    @Bindable var store: BrandMatchStore
    let pick: BMPick
    @State private var showsHistory = false

    private var brand: BMBrand { pick.brand }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                    .padding(.bottom, 4)

                BMPriceCard(brand: brand, budget: 6 - store.persona.economy)

                BMCompatibilityView(persona: store.persona, brand: brand)
                    .bmCard()

                reasons
                    .padding(.top, 4)

                if let t = brand.targetPersona {
                    group("こんな人に合う") {
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

                notes
            }
            .padding(20)
        }
        .background(BMTokens.ground)
        .safeAreaInset(edge: .bottom) { actionBar }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 14) {
            BMLogoTile(brand: brand, width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(brand.nameEn)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(BMTokens.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(brand.nameJa).font(.system(size: 13)).foregroundStyle(BMTokens.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: 相棒より: 合う理由 (表にせず、相棒の吹き出しにハッシュタグで)

    private var reasons: some View {
        let tags = pick.reasonTags
        return HStack(alignment: .top, spacing: 10) {
            BMPartnerIcon(persona: store.persona, size: 36)
            VStack(alignment: .leading, spacing: 6) {
                Text("相棒より")
                    .font(.system(size: 12))
                    .foregroundStyle(BMTokens.muted)
                VStack(alignment: .leading, spacing: 14) {
                    Text("このブランドをすすめる理由は、この \(tags.count) つだよ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(tags) { t in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#" + t.tag)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(BMTokens.ink)
                            Text(t.text)
                                .font(.system(size: 13))
                                .foregroundStyle(BMTokens.muted)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BMTokens.surface, in: bubbleShape)
                .overlay(bubbleShape.stroke(BMTokens.border, lineWidth: 1))
            }
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16,
                               topTrailingRadius: 16, style: .continuous)
    }

    // MARK: 注意事項 (ページの下)

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            note("あなたとの相性 (好みの一致度・チャート・こんな人に合う) は、ファッションタイプとブランドの特徴から IRODORI が見立てたものです。")
            note("価格帯は、トップスの通常の定価をもとにした 5 段階です。創業・運営・価格は 2026 年 10 月の調査値です。")
            note("IRODORI とブランドの提携はありません。")
            if let img = brand.image, let src = img.source {
                let credit = "画像の出典: " + src + ((img.license ?? "").isEmpty ? "" : "（\(img.license ?? "")）")
                if let page = img.sourcePage, let url = URL(string: page) {
                    Link(destination: url) { note(credit, underline: true) }
                } else {
                    note(credit)
                }
            }
        }
        .padding(.top, 8)
    }

    private func note(_ text: String, underline: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("※")
            Text(text).underline(underline).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11))
        .foregroundStyle(BMTokens.faint)
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

    private var founded: String? {
        // 括弧の補足は省く (語の途中で折れて読みにくいため。全文は歴史に)
        let f = brand.founder.map { String($0.split(separator: "（").first ?? Substring($0)).trimmingCharacters(in: .whitespaces) }
        guard let y = brand.foundedYear else { return f }
        if let f, !f.isEmpty { return "\(y) 年・" + f }
        return "\(y) 年"
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(BMTokens.muted)
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

// MARK: - 価格帯 (詳細の上部)

/// 手に入るかを最初に判断できるように: 段階の名前 + トップスの目安の金額 + 5 段階のメーター +
/// あなたの予算感との比べ + 公式の価格の例 (調査値があるときだけ)
struct BMPriceCard: View {
    let brand: BMBrand
    /// あなたのちょうどいい段階 (6 − 経済の点、1〜5)
    let budget: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("価格帯")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                    Spacer(minLength: 8)
                    Text(fitText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BMTokens.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BMTokens.raised, in: RoundedRectangle(cornerRadius: BMTokens.chipRadius, style: .continuous))
                }
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(brand.tierLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(BMTokens.ink)
                    Text("トップス \(brand.tierGuide) が目安")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(BMTokens.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                meter
            }
            .padding(16)

            let examples = brand.priceExamples
            if !examples.isEmpty {
                BMRule(leading: 16)
                VStack(alignment: .leading, spacing: 8) {
                    Text("公式の価格の例")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                    ForEach(Array(examples.enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            if !e.item.isEmpty {
                                Text(e.item)
                                    .font(.system(size: 13))
                                    .foregroundStyle(BMTokens.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(width: 116, alignment: .leading)
                            }
                            Text(e.price)
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                                .foregroundStyle(BMTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(16)
            }
        }
        .bmCard()
    }

    /// 5 段階のメーター: 当てはまる段階まで黒で埋める (端に「プチプラ」「ラグジュアリー」)
    private var meter: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i <= brand.tier ? BMTokens.ink : BMTokens.border)
                        .frame(height: 8)
                }
            }
            HStack {
                Text(BMBrand.tierLabels[1])
                Spacer()
                Text(BMBrand.tierLabels[5])
            }
            .font(.system(size: 11))
            .foregroundStyle(BMTokens.faint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("価格帯 5 段階中 \(brand.tier)、\(brand.tierLabel)。トップス \(brand.tierGuide) が目安。\(fitText)"))
    }

    /// あなたの予算感 (ファッションタイプの経済の点) との比べ
    private var fitText: String {
        let gap = Double(brand.tier) - budget
        if abs(gap) <= 0.5 { return "あなたの予算感にぴったり" }
        if gap < 0 { return "あなたの予算感より手頃" }
        return gap <= 1.5 ? "あなたの予算感より少し上" : "あなたの予算感より上"
    }
}
