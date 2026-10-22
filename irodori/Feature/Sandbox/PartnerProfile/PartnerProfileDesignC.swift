//
//  PartnerProfileDesignC.swift
//  irodori - Sandbox
//
//  案C「相棒の見立てノート」
//  相棒が「たぶんこうでしょ？」と話しかけ、その場で答え合わせ (合ってる／ちょっと違う)。
//  理解度は「今日のミッション 3つ」と「60%までの道のり」で見せ、毎日少しずつ進む感覚を出す。
//  答え合わせ済み・わかった特徴は下の「あなたのこと」にまとめて残る。
//

import SwiftUI

struct PartnerProfileDesignC: View {
    @Bindable var store: PartnerProfileSandboxStore
    @State private var openTrait: PartnerTraitMock?

    /// 答え合わせ待ちの見立て (最大2つずつ出す)
    private var pendingGuesses: [PartnerTraitMock] {
        store.traits(unlocked: true)
            .filter { store.verdicts[$0.id] == nil && store.confidence($0) < 3 }
            .prefix(2)
            .map { $0 }
    }

    private var knownTraits: [PartnerTraitMock] {
        store.traits(unlocked: true).filter { store.verdicts[$0.id] != nil || store.confidence($0) == 3 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                compactHeader
                todayMissions
                if !pendingGuesses.isEmpty { guessesSection }
                knownSection
                roadTo60
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .sheet(item: $openTrait) { t in
            PartnerTraitDetailSheet(trait: t, store: store).presentationDetents([.medium])
        }
    }

    // MARK: - ヘッダー

    private var compactHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(RenewalTokens.border, lineWidth: 4)
                Circle().trim(from: 0, to: CGFloat(store.pct) / 100)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                PartnerIconImage(size: 46)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("理解度 \(store.pct)%")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(store.stage.name) ・ わかったこと \(knownTraits.count)つ")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer()
        }
        .animation(.easeOut(duration: 0.4), value: store.pct)
    }

    // MARK: - 今日のミッション

    private var todayMissions: some View {
        let list = Array(store.activeMissions.prefix(3))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("今日のミッション")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                let gain = list.reduce(0) { $0 + $1.points }
                if gain > 0 {
                    Text("全部で +\(gain)%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.accentPink)
                }
            }
            if list.isEmpty {
                Text("今日の分はぜんぶクリア。また明日ね")
                    .font(.system(size: 13))
                    .foregroundStyle(RenewalTokens.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .renewalCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().padding(.leading, 44) }
                        PartnerMissionRow(mission: m, store: store)
                    }
                }
                .renewalCard()
            }
        }
    }

    // MARK: - 見立て (答え合わせ)

    private var guessesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近わかってきたこと")
                .font(.system(size: 15, weight: .semibold))
            ForEach(pendingGuesses) { t in
                guessBubble(t)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
    }

    private func guessBubble(_ t: PartnerTraitMock) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PartnerIconImage(size: 32)
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(t.title)は「\(t.value)」でしょ？")
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let e = t.evidence.first {
                        Text("理由: \(e)")
                            .font(.system(size: 11))
                            .foregroundStyle(RenewalTokens.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 8) {
                    answerChip("ちょっと違う", filled: false) { store.verdict(t, agree: false) }
                    answerChip("合ってる", filled: true) { store.verdict(t, agree: true) }
                    Spacer()
                }
            }
            .padding(14)
            .background(RenewalTokens.surface)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14).stroke(RenewalTokens.border))
        }
    }

    private func answerChip(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            withAnimation(.easeOut(duration: 0.3)) { action() }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(filled ? .white : RenewalTokens.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(filled ? RenewalTokens.primaryFill : RenewalTokens.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(filled ? Color.clear : RenewalTokens.controlBorder))
        }
        .buttonStyle(.plain)
    }

    // MARK: - あなたのこと (わかった特徴)

    private var knownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("あなたのこと")
                .font(.system(size: 15, weight: .semibold))
            Text(store.summary)
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            if knownTraits.isEmpty {
                Text("答え合わせした特徴がここにたまるよ")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            } else {
                PartnerWrap(spacing: 8) {
                    ForEach(knownTraits) { t in
                        Button { openTrait = t } label: { knownChip(t) }.buttonStyle(.plain)
                    }
                }
            }
            let locked = store.traits(unlocked: false)
            if let next = locked.first {
                HStack(spacing: 6) {
                    Image(systemName: "lock").font(.system(size: 11))
                    Text("次にわかりそう: \(next.title)（\(next.unlockHint)）")
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(RenewalTokens.muted)
            }
        }
    }

    private func knownChip(_ t: PartnerTraitMock) -> some View {
        HStack(spacing: 6) {
            if !t.swatches.isEmpty {
                PartnerProfileSwatches(colors: t.swatches, size: 11)
            } else {
                Image(systemName: t.icon).font(.system(size: 11)).foregroundStyle(RenewalTokens.muted)
            }
            Text(t.value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(store.verdicts[t.id] == false ? RenewalTokens.muted : RenewalTokens.ink)
                .strikethrough(store.verdicts[t.id] == false, color: RenewalTokens.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RenewalTokens.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(RenewalTokens.border))
    }

    // MARK: - 60% までの道のり

    private var roadTo60: some View {
        let points: [(String, Int)] = [("1日目", 25), ("2日目", 45), ("3日目", 52), ("4日目", 57), ("5日目", 62)]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("「しんゆう」までの目安")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("62%で1週間先まで予定コーデを組める")
                    .font(.system(size: 10))
                    .foregroundStyle(RenewalTokens.muted)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points, id: \.0) { label, v in
                    let reached = store.pct >= v
                    VStack(spacing: 4) {
                        Text("\(v)%")
                            .font(.system(size: 10, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(reached ? RenewalTokens.ink : RenewalTokens.muted)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(reached ? RenewalTokens.ink : RenewalTokens.border)
                            .frame(height: CGFloat(v) * 1.1)
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .renewalCard()
        }
    }
}

/// チップを折り返して並べる
struct PartnerWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            w = max(w, x - spacing)
        }
        return CGSize(width: min(w, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
