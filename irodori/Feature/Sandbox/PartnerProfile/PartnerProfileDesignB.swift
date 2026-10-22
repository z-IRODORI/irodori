//
//  PartnerProfileDesignB.swift
//  irodori - Sandbox
//
//  案B「実績と発見」
//  上: 理解度リング + 5つのステージの道のり (できるようになることつき)。
//  中: 相棒が見つけた特徴を横スクロールのカードで。まだのものは鍵つきで条件を見せる。
//  下: ミッションを実績バッジの一覧で。タップで条件と進みを出す。
//

import SwiftUI

struct PartnerProfileDesignB: View {
    @Bindable var store: PartnerProfileSandboxStore
    @State private var openMission: PartnerMissionCatalog.Def?
    @State private var openTrait: PartnerTraitMock?
    @State private var gauge: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ringHeader
                stageRoad
                discoveries
                badges
            }
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.surface)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { gauge = CGFloat(store.pct) / 100 } }
        .onChange(of: store.pct) { _, v in withAnimation(.easeOut(duration: 0.5)) { gauge = CGFloat(v) / 100 } }
        .sheet(item: $openMission) { m in
            missionSheet(m).presentationDetents([.height(300)])
        }
        .sheet(item: $openTrait) { t in
            PartnerTraitDetailSheet(trait: t, store: store).presentationDetents([.medium])
        }
    }

    // MARK: - リング

    private var ringHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(RenewalTokens.rule, lineWidth: 8)
                Circle().trim(from: 0, to: gauge)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    PartnerIconImage(size: 72)
                    Text("\(store.pct)%")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 160, height: 160)
            Text("あなたのことを「\(store.stage.name)」くらいわかってきた")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
            let cleared = PartnerMissionCatalog.all.filter(store.isDone).count
            Text("実績 \(cleared)/\(PartnerMissionCatalog.all.count)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(RenewalTokens.muted)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.3), value: store.pct)
    }

    // MARK: - ステージの道のり

    private var stageRoad: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(PartnerMissionCatalog.stages.enumerated()), id: \.element.index) { i, s in
                let reached = store.pct >= s.at_pct
                let unlock = PartnerMissionCatalog.unlocks[i]
                let isCurrent = store.stage.index == s.index
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(reached ? RenewalTokens.ink : RenewalTokens.surface)
                            .overlay(Circle().stroke(reached ? RenewalTokens.ink : RenewalTokens.controlBorder, lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                            .padding(.top, 3)
                        if i < PartnerMissionCatalog.stages.count - 1 {
                            Rectangle()
                                .fill(store.pct >= PartnerMissionCatalog.stages[i + 1].at_pct ? RenewalTokens.ink : RenewalTokens.border)
                                .frame(width: 1.5)
                                .frame(minHeight: 30)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(s.name)
                                .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                .foregroundStyle(reached ? RenewalTokens.ink : RenewalTokens.muted)
                            Text("\(s.at_pct)%〜 ・ \(PartnerMissionCatalog.stageDays[s.index] ?? "")")
                                .font(.system(size: 11))
                                .monospacedDigit()
                                .foregroundStyle(RenewalTokens.muted)
                            if isCurrent {
                                Text("いまここ")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(RenewalTokens.accentPink)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(unlock.1)
                            .font(.system(size: 12))
                            .foregroundStyle(RenewalTokens.muted)
                            .padding(.bottom, 10)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 発見 (特徴)

    private var discoveries: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("相棒が見つけたあなた")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(store.traits(unlocked: true).count)/\(PartnerTraitCatalog.all.count)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.traits(unlocked: true)) { t in
                        Button { openTrait = t } label: { traitCard(t) }.buttonStyle(.plain)
                    }
                    ForEach(store.traits(unlocked: false).prefix(3)) { t in
                        lockedCard(t)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func traitCard(_ t: PartnerTraitMock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: t.icon).font(.system(size: 13)).foregroundStyle(RenewalTokens.muted)
                Spacer()
                PartnerProfileConfidenceDots(level: store.confidence(t))
            }
            Text(t.title)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
            Text(t.value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if !t.swatches.isEmpty {
                PartnerProfileSwatches(colors: t.swatches, size: 16)
            } else if let m = t.meter {
                PartnerProfileMeter(left: m.left, right: m.right, value: m.value)
            } else {
                Text(store.confidence(t) == 3 ? "わかった" : store.verdicts[t.id] == nil ? "答え合わせする" : "見直し中")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.confidence(t) == 3 ? RenewalTokens.muted : RenewalTokens.accentPink)
            }
        }
        .padding(12)
        .frame(width: 148, height: 150, alignment: .topLeading)
        .renewalCard()
    }

    private func lockedCard(_ t: PartnerTraitMock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock").font(.system(size: 13)).foregroundStyle(RenewalTokens.controlBorder)
            Text(t.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
            Spacer(minLength: 0)
            Text(t.unlockHint)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 148, height: 150, alignment: .topLeading)
        .background(RenewalTokens.raised)
        .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
    }

    // MARK: - 実績バッジ

    private var badges: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("実績")
                .font(.system(size: 15, weight: .semibold))
            ForEach(PartnerMissionCatalog.stages, id: \.index) { s in
                let list = store.missions(stage: s.index)
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(s.name)  \(list.filter(store.isDone).count)/\(list.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                        ForEach(list) { m in
                            Button { openMission = m } label: { badge(m) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func badge(_ m: PartnerMissionCatalog.Def) -> some View {
        let done = store.isDone(m)
        let ratio = CGFloat(store.current(m)) / CGFloat(m.target)
        return VStack(spacing: 6) {
            ZStack {
                Circle().fill(done ? RenewalTokens.ink : RenewalTokens.raised)
                if !done && ratio > 0 {
                    Circle().trim(from: 0, to: ratio)
                        .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(1.5)
                }
                Image(systemName: m.icon)
                    .font(.system(size: 17))
                    .foregroundStyle(done ? .white : RenewalTokens.muted)
            }
            .frame(width: 50, height: 50)
            Text(m.title)
                .font(.system(size: 10))
                .foregroundStyle(done ? RenewalTokens.ink : RenewalTokens.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 26, alignment: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(m.title)、\(done ? "クリア" : "未クリア")")
    }

    private func missionSheet(_ m: PartnerMissionCatalog.Def) -> some View {
        let done = store.isDone(m)
        return VStack(spacing: 14) {
            Image(systemName: m.icon)
                .font(.system(size: 26))
                .foregroundStyle(done ? .white : RenewalTokens.ink)
                .frame(width: 64, height: 64)
                .background(Circle().fill(done ? RenewalTokens.ink : RenewalTokens.raised))
            Text(m.title).font(.system(size: 17, weight: .bold))
            Text(done ? "クリア済み ・ 理解度 +\(m.points)%" : "\(store.current(m))/\(m.target) ・ クリアで理解度 +\(m.points)%")
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(RenewalTokens.muted)
            if !m.hint.isEmpty {
                Text(m.hint).font(.system(size: 13)).foregroundStyle(RenewalTokens.ink)
            }
            Button(done ? "もとに戻す (Sandbox)" : "1つ進める (Sandbox)") {
                withAnimation { store.tap(m) }
                openMission = nil
            }
            .buttonStyle(RenewalPrimaryButtonStyle(filled: !done))
            .padding(.top, 4)
        }
        .padding(24)
    }
}
