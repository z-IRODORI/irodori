//
//  PartnerProfileDesignD.swift
//  irodori - Sandbox
//
//  案D「シンプル」— 案A (カルテ) と案B (実績) の間。
//  文字は最小限にして、ひと目で「どれくらいわかってくれたか」「次に何をすればいいか」が伝わる形。
//  罫線をやめて、角丸を少し大きくした白カード + うすい影で柔らかく見せる。
//

import SwiftUI

private enum Soft {
    static let radius: CGFloat = 18
    static let tileRadius: CGFloat = 16
}

private extension View {
    /// 罫線なしの白カード (IRODORI の白カード + うすい影)
    func softCard(_ radius: CGFloat = Soft.radius) -> some View {
        background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

struct PartnerProfileDesignD: View {
    @Bindable var store: PartnerProfileSandboxStore
    @State private var openTrait: PartnerTraitMock?
    @State private var showAllMissions = false
    @State private var gauge: CGFloat = 0

    private var openTraits: [PartnerTraitMock] { store.traits(unlocked: true) }
    private var lockedTraits: [PartnerTraitMock] { store.traits(unlocked: false) }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                missions
                traits
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { gauge = CGFloat(store.pct) / 100 } }
        .onChange(of: store.pct) { _, v in withAnimation(.easeOut(duration: 0.5)) { gauge = CGFloat(v) / 100 } }
        .sheet(item: $openTrait) { t in
            PartnerSoftTraitSheet(trait: t, store: store)
                .presentationDetents([.height(330)])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showAllMissions) {
            PartnerAllMissionsSheet(store: store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    // MARK: - 理解度

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(RenewalTokens.rule, lineWidth: 7)
                Circle().trim(from: 0, to: gauge)
                    .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                PartnerIconImage(size: 92)
            }
            .frame(width: 124, height: 124)

            VStack(spacing: 4) {
                Text("\(store.pct)%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("相棒の理解度")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
            }

            stageDots
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.4), value: store.pct)
    }

    /// 5つの段階を点で。いまの段階だけ名前を出す
    private var stageDots: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(PartnerMissionCatalog.stages, id: \.index) { s in
                    let reached = store.pct >= s.at_pct
                    let current = store.stage.index == s.index
                    Capsule()
                        .fill(reached ? RenewalTokens.ink : RenewalTokens.border)
                        .frame(width: current ? 22 : 8, height: 8)
                }
            }
            HStack(spacing: 6) {
                Text(store.stage.name)
                    .font(.system(size: 13, weight: .semibold))
                if let next = store.nextStage {
                    Text("あと\(next.at_pct - store.pct)%で\(next.name)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 次のミッション

    private var missions: some View {
        let list = Array(store.activeMissions.prefix(3))
        let cleared = PartnerMissionCatalog.all.filter(store.isDone).count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("次のミッション")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    Haptic.impact(.soft)
                    showAllMissions = true
                } label: {
                    HStack(spacing: 3) {
                        Text("実績 \(cleared)/\(PartnerMissionCatalog.all.count)")
                            .monospacedDigit()
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                }
                .buttonStyle(.plain)
            }
            if list.isEmpty {
                Text("ぜんぶクリア！")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .softCard()
            } else {
                VStack(spacing: 4) {
                    ForEach(list) { m in
                        PartnerSoftMissionRow(mission: m, store: store)
                    }
                }
                .padding(6)
                .softCard()
            }
        }
    }

    // MARK: - あなたのこと

    private var traits: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("あなたのこと")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(openTraits.count)/\(PartnerTraitCatalog.all.count)")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(openTraits) { t in
                    Button {
                        Haptic.impact(.soft)
                        openTrait = t
                    } label: { traitTile(t) }
                    .buttonStyle(.plain)
                }
                if let next = lockedTraits.first {
                    lockedTile(next)
                }
            }
        }
    }

    private func traitTile(_ t: PartnerTraitMock) -> some View {
        let waiting = store.verdicts[t.id] == nil && store.confidence(t) < 3
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !t.swatches.isEmpty {
                    PartnerProfileSwatches(colors: t.swatches, size: 18)
                } else {
                    Image(systemName: t.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(RenewalTokens.raised))
                }
                Spacer()
                if waiting {
                    // 答え合わせ待ちはピンクの点だけで知らせる
                    Circle().fill(RenewalTokens.accentPink).frame(width: 7, height: 7)
                }
            }
            .frame(height: 30)
            Spacer(minLength: 0)
            Text(t.value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
            Text(t.title)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .softCard(Soft.tileRadius)
        .accessibilityElement(children: .combine)
        .accessibilityHint(waiting ? "答え合わせできます" : "")
    }

    private func lockedTile(_ t: PartnerTraitMock) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(RenewalTokens.muted)
                .frame(width: 30, height: 30)
                .background(Circle().fill(RenewalTokens.surface))
            Spacer(minLength: 0)
            Text("あと\(lockedTraits.count)つ")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RenewalTokens.muted)
            Text(t.unlockHint)
                .font(.system(size: 11))
                .foregroundStyle(RenewalTokens.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(RenewalTokens.raised)
        .clipShape(RoundedRectangle(cornerRadius: Soft.tileRadius, style: .continuous))
    }
}

// MARK: - ミッションの行 (案D)

struct PartnerSoftMissionRow: View {
    let mission: PartnerMissionCatalog.Def
    @Bindable var store: PartnerProfileSandboxStore

    var body: some View {
        let done = store.isDone(mission)
        let cur = store.current(mission)
        Button {
            Haptic.impact(.soft)
            withAnimation(.easeOut(duration: 0.3)) { store.tap(mission) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? RenewalTokens.ink : RenewalTokens.raised)
                    if mission.target > 1 && !done && cur > 0 {
                        Circle()
                            .trim(from: 0, to: CGFloat(cur) / CGFloat(mission.target))
                            .stroke(RenewalTokens.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(1.5)
                    }
                    Image(systemName: done ? "checkmark" : mission.icon)
                        .font(.system(size: 14, weight: done ? .bold : .medium))
                        .foregroundStyle(done ? .white : RenewalTokens.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if mission.target > 1 && !done {
                        Text("\(cur)/\(mission.target)")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                Spacer(minLength: 8)
                Text("+\(mission.points)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.accentPink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(done ? RenewalTokens.raised : RenewalTokens.accentPink.opacity(0.08)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mission.title)、\(done ? "クリア" : "\(cur)/\(mission.target)")、理解度プラス\(mission.points)%")
    }
}

// MARK: - 実績の一覧 (シート)

struct PartnerAllMissionsSheet: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(PartnerMissionCatalog.stages, id: \.index) { s in
                        let list = store.missions(stage: s.index)
                        let reached = store.pct >= s.at_pct
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(s.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(reached ? RenewalTokens.ink : RenewalTokens.muted)
                                Text("\(s.at_pct)%〜")
                                    .font(.system(size: 11))
                                    .monospacedDigit()
                                    .foregroundStyle(RenewalTokens.muted)
                                Spacer()
                                Text("\(list.filter(store.isDone).count)/\(list.count)")
                                    .font(.system(size: 12, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(RenewalTokens.muted)
                            }
                            Text(PartnerMissionCatalog.unlocks[s.index - 1].1)
                                .font(.system(size: 12))
                                .foregroundStyle(RenewalTokens.muted)
                            VStack(spacing: 4) {
                                ForEach(list) { m in PartnerSoftMissionRow(mission: m, store: store) }
                            }
                            .padding(6)
                            .softCard()
                        }
                    }
                }
                .padding(20)
            }
            .background(RenewalTokens.ground)
            .navigationTitle("実績")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(RenewalTokens.ink)
                }
            }
        }
    }
}

// MARK: - 特徴の詳細 (案D: 文字を絞った版)

struct PartnerSoftTraitSheet: View {
    let trait: PartnerTraitMock
    @Bindable var store: PartnerProfileSandboxStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                if !trait.swatches.isEmpty {
                    PartnerProfileSwatches(colors: trait.swatches, size: 28)
                } else {
                    Image(systemName: trait.icon)
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(RenewalTokens.raised))
                }
                Text(trait.title)
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                Text(trait.value)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            if let m = trait.meter {
                PartnerProfileMeter(left: m.left, right: m.right, value: m.value)
                    .padding(.horizontal, 24)
            }

            if let e = trait.evidence.first {
                Label(e, systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(RenewalTokens.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(RenewalTokens.raised))
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                answer("ちょっと違う", agree: false)
                answer("合ってる", agree: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private func answer(_ title: String, agree: Bool) -> some View {
        let chosen = store.verdicts[trait.id] == agree
        return Button {
            Haptic.impact(.soft)
            store.verdict(trait, agree: agree)
            dismiss()
        } label: {
            HStack(spacing: 6) {
                if chosen { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(agree ? .white : RenewalTokens.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(agree ? RenewalTokens.primaryFill : RenewalTokens.raised))
        }
        .buttonStyle(.plain)
    }
}
