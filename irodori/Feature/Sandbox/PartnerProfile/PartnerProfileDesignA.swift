//
//  PartnerProfileDesignA.swift
//  irodori - Sandbox
//
//  案A「ふたりの交換日記」
//  相棒が見つけたあなたのことを、日付つきの日記として1ページずつ書いてくれる。
//  ページの最後には必ず相棒からの問いかけがあり、返事をするとその場で相棒が返す (= 交換日記)。
//  返事は次の提案に効き、ページの色テープで「何の発見か」がひと目でわかる。
//

import SwiftUI

struct PartnerProfileDesignA: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Bindable var discoveries: PartnerDiscoveryState
    @State private var showMissions = false

    private var pages: [PartnerDiscovery] { discoveries.discoveries(pct: store.pct) }
    private var waitingCount: Int { pages.filter { discoveries.answers[$0.id] == nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PartnerUnderstandingStrip(store: store) { showMissions = true }
                cover
                if pages.isEmpty {
                    emptyPage
                } else {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { i, d in
                        page(d, isNew: i == 0)
                    }
                }
                if let next = discoveries.upcoming(pct: store.pct).first {
                    nextPage(next)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .sheet(isPresented: $showMissions) {
            PartnerAllMissionsSheet(store: store).presentationCornerRadius(28)
        }
    }

    // MARK: - 表紙

    private var cover: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ふたりの交換日記")
                    .font(.system(size: 22, weight: .bold))
                Text(waitingCount > 0 ? "返事待ちのページが\(waitingCount)つあるよ" : "ぜんぶ返事したね。次のページを書いてるところ")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer()
            // 色テープの束 (ページの色の数)
            HStack(spacing: -6) {
                ForEach(Array(Set(pages.map(\.hue))).sorted { $0.rawValue < $1.rawValue }, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 3).fill(h.wash)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(h.mid, lineWidth: 1))
                        .frame(width: 14, height: 34)
                        .rotationEffect(.degrees(Double(h.rawValue.count % 3) * 6 - 6))
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - ページ

    private func page(_ d: PartnerDiscovery, isNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 日付 + テープ
            HStack(alignment: .center) {
                Text(d.date)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(d.hue.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 3).fill(d.hue.wash)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(d.hue.mid.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                    )
                    .rotationEffect(.degrees(-2))
                if d.rarity != .normal {
                    PartnerRarityBadge(rarity: d.rarity, hue: d.hue)
                }
                Spacer()
                if isNew && discoveries.answers[d.id] == nil {
                    Text("NEW")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(RenewalTokens.accentPink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(RenewalTokens.accentPink, lineWidth: 1.5))
                        .rotationEffect(.degrees(8))
                }
            }

            // 相棒の文
            VStack(alignment: .leading, spacing: 8) {
                Text(d.headline)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(d.body)
                    .font(.system(size: 14))
                    .foregroundStyle(RenewalTokens.ink.opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PartnerDiscoveryVizView(viz: d.viz, hue: d.hue)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(d.hue.wash.opacity(0.6)))

            // 交換日記の返事欄
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line").font(.system(size: 10, weight: .semibold))
                    Text("あなたの返事")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(d.hue.ink)
                .padding(.bottom, 8)
                PartnerDigView(discovery: d, state: discoveries)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(d.hue.wash))
        }
        .padding(16)
        .background(
            // うすい罫線の紙
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RenewalTokens.surface)
                .overlay(alignment: .leading) {
                    Rectangle().fill(d.hue.mid.opacity(0.6)).frame(width: 3).padding(.vertical, 18)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }

    private var emptyPage: some View {
        VStack(spacing: 10) {
            PartnerIconImage(size: 56)
            Text("まだ1ページ目を書いてるところ")
                .font(.system(size: 14, weight: .semibold))
            Text("服を5点おぼえさせると、最初のページが届くよ")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .partnerSoftCard(20)
    }

    // MARK: - 次のページ (予告)

    private func nextPage(_ d: PartnerDiscovery) -> some View {
        let need = max(0, d.unlockAt - store.pct)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("次のページ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(d.hue.ink)
                Spacer()
                Text("理解度 あと\(need)%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            Text(d.teaser)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
            // 伏せ字の本文
            VStack(alignment: .leading, spacing: 6) {
                ForEach([0.9, 0.75, 0.5], id: \.self) { w in
                    GeometryReader { geo in
                        Capsule().fill(d.hue.mid.opacity(0.35)).frame(width: geo.size.width * w)
                    }
                    .frame(height: 9)
                }
            }
            HStack(spacing: 6) {
                PartnerIconImage(size: 22)
                Text("いま書いてるところ。もう少しで見せられそう")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(d.hue.mid, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}
