//
//  PartnerProfileDesignC.swift
//  irodori - Sandbox
//
//  案C「あなたの色と形」
//  あなたを「色のしゃぼん玉」と「いつもの組み合わせ」で絵にする。
//  しゃぼん玉の大きさ = クローゼットの色の割合。タップすると相棒がその色の話をしてくれる (深掘り)。
//  下に、その絵の「理由」になった発見がテープつきで並ぶ。
//

import SwiftUI

private struct PaletteBubble: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color
    let count: Int
    /// 相棒のひとこと (タップで出る)
    let talk: String
    /// 関連する発見
    let discoveryId: String?
}

private let bubbles: [PaletteBubble] = [
    .init(id: "black", name: "ブラック", color: Color(white: 0.12), count: 7,
          talk: "いちばん多い色。決めるのが速くなる、あなたの安心スイッチ。寒い日はさらに増えるよ", discoveryId: "black_fast"),
    .init(id: "white", name: "ホワイト", color: .white, count: 4,
          talk: "白シャツは「ちゃんとしたい日」担当。予定がある日に出番が多いの", discoveryId: "white_shirt"),
    .init(id: "gray", name: "グレー", color: Color(white: 0.62), count: 3,
          talk: "パーカーやスウェットのラクな日の色。休日に寄ってる", discoveryId: nil),
    .init(id: "blue", name: "ブルー", color: Color(red: 0.30, green: 0.45, blue: 0.68), count: 2,
          talk: "ジーンズの色。迷ったらまずここから組むよね。金曜に増える色でもある", discoveryId: "denim_hero"),
    .init(id: "brown", name: "ブラウン", color: Color(red: 0.50, green: 0.33, blue: 0.22), count: 2,
          talk: "数は少ないけど「いいね」の案によく入ってた。実は次に増やしたい色かも", discoveryId: "hidden_color"),
    .init(id: "orange", name: "オレンジ", color: Color(red: 0.95, green: 0.50, blue: 0.15), count: 1,
          talk: "大きいと苦手、小物ならOK。そんな色", discoveryId: "orange_area"),
    .init(id: "red", name: "レッド", color: Color(red: 0.82, green: 0.18, blue: 0.20), count: 1,
          talk: "30日出番なし。黒のパンツと合わせれば浮きにくいよ。そろそろ起こしてあげる？", discoveryId: nil),
    .init(id: "beige", name: "ベージュ", color: Color(red: 0.86, green: 0.78, blue: 0.64), count: 1,
          talk: "チノの色。白シャツとの組み合わせがいちばん「あなたらしい」って思ってる", discoveryId: nil),
]

struct PartnerProfileDesignC: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Bindable var discoveries: PartnerDiscoveryState
    @State private var showMissions = false
    @State private var selected: PaletteBubble? = bubbles.first
    @State private var openCard: PartnerDiscovery?
    @State private var appear = false

    private var found: [PartnerDiscovery] { discoveries.discoveries(pct: store.pct) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PartnerUnderstandingStrip(store: store) { showMissions = true }
                portrait
                outfit
                reasons
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.35).delay(0.1)) { appear = true } }
        .sheet(isPresented: $showMissions) {
            PartnerAllMissionsSheet(store: store).presentationCornerRadius(28)
        }
        .sheet(item: $openCard) { d in
            PartnerDiscoverySheet(discovery: d, discoveries: discoveries)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    // MARK: - 色のしゃぼん玉

    private var portrait: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("あなたを色にすると")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                Text("静かなモノトーンに、\nブルーをひとさじ")
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            bubbleCloud
                .frame(height: 230)
            if let s = selected {
                HStack(alignment: .top, spacing: 10) {
                    PartnerIconImage(size: 32)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Circle().fill(s.color)
                                .overlay(Circle().stroke(Color.black.opacity(0.12)))
                                .frame(width: 12, height: 12)
                            Text("\(s.name) \(s.count)点")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(s.talk)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                        if let id = s.discoveryId, let d = found.first(where: { $0.id == id }) {
                            Button {
                                Haptic.impact(.soft)
                                openCard = d
                            } label: {
                                HStack(spacing: 4) {
                                    Text("この話をもっと聞く")
                                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                                }
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(d.hue.ink)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
                            .fill(RenewalTokens.surface)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                }
                .id(s.id)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [PartnerHue.sky.wash, PartnerHue.lilac.wash, PartnerHue.pink.wash.opacity(0.7)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    /// 決め打ちの配置 (大きい順に中央から)
    private var bubbleCloud: some View {
        let spots: [(CGFloat, CGFloat)] = [
            (0.42, 0.45), (0.72, 0.30), (0.70, 0.74), (0.18, 0.22),
            (0.20, 0.76), (0.90, 0.55), (0.46, 0.88), (0.48, 0.10),
        ]
        return GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height) / 230
            ZStack {
                ForEach(Array(bubbles.enumerated()), id: \.element.id) { i, b in
                    let d = (30 + CGFloat(b.count) * 11) * unit
                    let isSel = selected?.id == b.id
                    Button {
                        Haptic.impact(.soft)
                        withAnimation(.spring(duration: 0.4)) { selected = b }
                    } label: {
                        ZStack {
                            Circle().fill(b.color)
                                .overlay(Circle().stroke(isSel ? RenewalTokens.ink : Color.black.opacity(b.color == .white ? 0.12 : 0), lineWidth: isSel ? 3 : 1))
                                .shadow(color: b.color.opacity(0.35), radius: isSel ? 10 : 4, y: 3)
                            if b.count >= 2 {
                                Text("\(b.count)")
                                    .font(.system(size: 12 + CGFloat(b.count), weight: .bold, design: .rounded))
                                    .foregroundStyle(b.id == "white" || b.id == "beige" ? RenewalTokens.ink : .white)
                            }
                        }
                        .frame(width: d, height: d)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(appear ? (isSel ? 1.08 : 1) : 0.2)
                    .position(x: geo.size.width * spots[i].0, y: geo.size.height * spots[i].1)
                    .accessibilityLabel("\(b.name) \(b.count)点")
                }
            }
        }
    }

    // MARK: - いつもの組み合わせ

    private var outfit: some View {
        let looks: [PartnerGarmentMock] = [
            .init(kind: .top, color: .white, name: "白シャツ"),
            .init(kind: .bottom, color: Color(red: 0.30, green: 0.45, blue: 0.68), name: "ジーンズ"),
            .init(kind: .shoes, color: Color(red: 0.50, green: 0.33, blue: 0.22), name: "ブラウンのスニーカー"),
        ]
        return HStack(spacing: 16) {
            VStack(spacing: -6) {
                PartnerGarmentView(garment: looks[0], size: 54)
                PartnerGarmentView(garment: looks[1], size: 58)
                PartnerGarmentView(garment: looks[2], size: 40)
            }
            .frame(width: 92)
            .padding(.vertical, 12)
            .background(Circle().fill(PartnerHue.lemon.wash).frame(width: 120, height: 120))
            VStack(alignment: .leading, spacing: 6) {
                Text("いちばんあなたらしい組み合わせ")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                Text("白シャツ × ジーンズ × ブラウンのスニーカー")
                    .font(.system(size: 16, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("「着る」と決めた日の3回に1回はこれ")
                    .font(.system(size: 12))
                    .foregroundStyle(PartnerHue.lemon.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .partnerSoftCard(22)
    }

    // MARK: - そう思った理由 (発見)

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("この絵になった理由")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(found.count)つの発見")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(found) { d in
                        Button {
                            Haptic.impact(.soft)
                            openCard = d
                        } label: { reasonCard(d) }
                        .buttonStyle(.plain)
                    }
                    if let next = discoveries.upcoming(pct: store.pct).first {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 12))
                            Text(next.teaser)
                                .font(.system(size: 12, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text("理解度 \(next.unlockAt)%で")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(RenewalTokens.muted)
                        .padding(14)
                        .frame(width: 170, height: 150, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RenewalTokens.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
            }
        }
    }

    private func reasonCard(_ d: PartnerDiscovery) -> some View {
        let answered = discoveries.answers[d.id] != nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: d.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(d.hue.ink)
                Spacer()
                if !answered {
                    Text("返事する")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(d.hue.ink))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(d.hue.ink)
                }
            }
            Text(d.headline)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(d.date)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(d.hue.ink)
        }
        .padding(14)
        .frame(width: 170, height: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(d.hue.wash))
    }
}
