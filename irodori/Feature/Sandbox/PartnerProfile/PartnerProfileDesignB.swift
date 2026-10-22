//
//  PartnerProfileDesignB.swift
//  irodori - Sandbox
//
//  案B「めくる発見カード」
//  相棒が見つけたあなたの一面が、伏せたカードで届く。タップでめくると発見が現れ、
//  「なんで？」でもう一段深掘り。レア度と色で、集める楽しさを出す。
//  まだのカードは「何の発見か」だけ予告して、ミッションへの動機にする。
//

import SwiftUI

struct PartnerProfileDesignB: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Bindable var discoveries: PartnerDiscoveryState
    @State private var showMissions = false
    @State private var openCard: PartnerDiscovery?

    private var cards: [PartnerDiscovery] { discoveries.discoveries(pct: store.pct) }
    private var upcoming: [PartnerDiscovery] { discoveries.upcoming(pct: store.pct) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PartnerUnderstandingStrip(store: store) { showMissions = true }
                if let today = cards.first {
                    todayCard(today)
                }
                collection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .sheet(isPresented: $showMissions) {
            PartnerAllMissionsSheet(store: store).presentationCornerRadius(28)
        }
        .sheet(item: $openCard) { d in
            PartnerDiscoverySheet(discovery: d, discoveries: discoveries)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    // MARK: - 今日の1枚

    private func todayCard(_ d: PartnerDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PartnerIconImage(size: 28)
                Text(discoveries.opened.contains(d.id) ? "今日の発見" : "今日の発見、めくってみて")
                    .font(.system(size: 15, weight: .bold))
            }
            PartnerFlipCard(discovery: d, isOpen: discoveries.opened.contains(d.id), large: true) {
                if discoveries.opened.contains(d.id) {
                    openCard = d
                } else {
                    withAnimation(.spring(duration: 0.6)) { _ = discoveries.opened.insert(d.id) }
                }
            }
            .frame(height: 230)
        }
    }

    // MARK: - コレクション

    private var collection: some View {
        let total = PartnerDiscoveryCatalog.all.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("あなたの発見")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(cards.count)/\(total)枚")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(cards.dropFirst()) { d in
                    PartnerFlipCard(discovery: d, isOpen: discoveries.opened.contains(d.id), large: false) {
                        if discoveries.opened.contains(d.id) {
                            openCard = d
                        } else {
                            withAnimation(.spring(duration: 0.6)) { _ = discoveries.opened.insert(d.id) }
                        }
                    }
                    .frame(height: 170)
                }
                ForEach(upcoming) { d in
                    lockedCard(d).frame(height: 170)
                }
            }
        }
    }

    private func lockedCard(_ d: PartnerDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lock.fill").font(.system(size: 11))
                Spacer()
                Text("理解度 \(d.unlockAt)%")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(d.hue.ink.opacity(0.6))
            Spacer(minLength: 0)
            Text(d.teaser)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(d.hue.mid, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }
}

// MARK: - めくれるカード

struct PartnerFlipCard: View {
    let discovery: PartnerDiscovery
    let isOpen: Bool
    let large: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptic.impact(isOpen ? .soft : .medium)
            onTap()
        } label: {
            ZStack {
                back.opacity(isOpen ? 0 : 1)
                front.opacity(isOpen ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .rotation3DEffect(.degrees(isOpen ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? discovery.headline : "伏せたカード。タップでめくる")
    }

    /// 裏: 色のグラデーションと「？」
    private var back: some View {
        let d = discovery
        return ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [d.hue.ink.opacity(0.85), d.hue.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
            // ドット柄
            Canvas { ctx, size in
                for x in stride(from: 8.0, to: size.width, by: 16) {
                    for y in stride(from: 8.0, to: size.height, by: 16) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(.white.opacity(0.18)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(spacing: large ? 10 : 6) {
                Image(systemName: d.icon)
                    .font(.system(size: large ? 30 : 22, weight: .semibold))
                Text(large ? "タップでめくる" : "めくる")
                    .font(.system(size: large ? 13 : 11, weight: .bold))
            }
            .foregroundStyle(.white)
            VStack {
                HStack {
                    Spacer()
                    if d.rarity != .normal {
                        Text(d.rarity.rawValue)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(d.hue.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white))
                    }
                }
                Spacer()
            }
            .padding(12)
        }
        .shadow(color: d.hue.ink.opacity(0.25), radius: 10, y: 5)
    }

    /// 表: 発見
    private var front: some View {
        let d = discovery
        return VStack(alignment: .leading, spacing: large ? 12 : 8) {
            HStack {
                Image(systemName: d.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(d.hue.ink)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white))
                Spacer()
                PartnerRarityBadge(rarity: d.rarity, hue: d.hue)
            }
            Text(d.headline)
                .font(.system(size: large ? 19 : 14, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(large ? 3 : 4)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if large {
                PartnerDiscoveryVizView(viz: d.viz, hue: d.hue)
            }
            HStack(spacing: 4) {
                Text("なんで？")
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(d.hue.ink)
        }
        .padding(large ? 16 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(d.hue.wash))
    }
}

// MARK: - 発見の詳細 (なんで？ → 深掘り)

struct PartnerDiscoverySheet: View {
    let discovery: PartnerDiscovery
    @Bindable var discoveries: PartnerDiscoveryState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let d = discovery
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PartnerRarityBadge(rarity: d.rarity, hue: d.hue)
                    Text(d.date)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(d.hue.ink)
                    Spacer()
                    Button("閉じる") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundStyle(RenewalTokens.ink)
                }
                Text(d.headline)
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 10) {
                    PartnerIconImage(size: 34)
                    Text(d.body)
                        .font(.system(size: 14))
                        .lineSpacing(5)
                        .padding(12)
                        .background(
                            UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 16, style: .continuous)
                                .fill(RenewalTokens.raised)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
                PartnerDiscoveryVizView(viz: d.viz, hue: d.hue)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(d.hue.wash))
                PartnerDigView(discovery: d, state: discoveries)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(d.hue.wash.opacity(0.7)))
            }
            .padding(20)
        }
    }
}
