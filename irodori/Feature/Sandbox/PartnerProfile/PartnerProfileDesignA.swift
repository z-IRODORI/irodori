//
//  PartnerProfileDesignA.swift
//  irodori - Sandbox
//
//  案A「あなたのカルテ」
//  上: 理解度のバーと今のステージ。中: 相棒がまとめたあなた + 特徴を4つのグループで一覧。
//  下: 今のステージのミッション。特徴の行は「合ってる／ちょっと違う」で答え合わせできる。
//

import SwiftUI

struct PartnerProfileDesignA: View {
    @Bindable var store: PartnerProfileSandboxStore
    @State private var openTrait: PartnerTraitMock?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                summaryCard
                ForEach(PartnerTraitMock.Group.allCases, id: \.self) { group in
                    traitGroup(group)
                }
                missionsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .sheet(item: $openTrait) { trait in
            PartnerTraitDetailSheet(trait: trait, store: store)
                .presentationDetents([.medium])
        }
    }

    // MARK: - ヘッダー (理解度)

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            PartnerIconImage(size: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("理解度")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                    Text("\(store.pct)%")
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    Text(store.stage.name)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RenewalTokens.raised)
                        .clipShape(Capsule())
                }
                stagedBar
                if let next = store.nextStage {
                    Text("あと\(next.at_pct - store.pct)%で「\(next.name)」")
                        .font(.system(size: 11))
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
        }
        .animation(.easeOut(duration: 0.4), value: store.pct)
    }

    /// ステージの区切りが入ったバー
    private var stagedBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RenewalTokens.border)
                Capsule().fill(RenewalTokens.ink)
                    .frame(width: geo.size.width * CGFloat(store.pct) / 100)
                ForEach(PartnerMissionCatalog.stages.dropFirst(), id: \.index) { s in
                    Rectangle().fill(RenewalTokens.ground)
                        .frame(width: 2)
                        .offset(x: geo.size.width * CGFloat(s.at_pct) / 100 - 1)
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: - 相棒のまとめ

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相棒から見たあなた")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
            Text(store.summary)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RenewalTokens.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .renewalCard()
    }

    // MARK: - 特徴

    private func traitGroup(_ group: PartnerTraitMock.Group) -> some View {
        let all = PartnerTraitCatalog.all.filter { $0.group == group }
        let open = all.filter { store.pct >= $0.unlockAt }
        let locked = all.filter { store.pct < $0.unlockAt }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(group.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(open.count)/\(all.count)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.muted)
            }
            VStack(spacing: 0) {
                ForEach(Array(open.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { Divider().padding(.leading, 44) }
                    Button { openTrait = t } label: { traitRow(t) }
                        .buttonStyle(.plain)
                }
                if let next = locked.first {
                    if !open.isEmpty { Divider().padding(.leading, 44) }
                    lockedRow(next, more: locked.count - 1)
                }
            }
            .renewalCard()
        }
    }

    private func traitRow(_ t: PartnerTraitMock) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: t.icon)
                .font(.system(size: 14))
                .frame(width: 20)
                .foregroundStyle(RenewalTokens.muted)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title)
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                HStack(spacing: 6) {
                    Text(t.value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                    if !t.swatches.isEmpty { PartnerProfileSwatches(colors: t.swatches, size: 12) }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                verdictMark(t)
                PartnerProfileConfidenceDots(level: store.confidence(t))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RenewalTokens.controlBorder)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func verdictMark(_ t: PartnerTraitMock) -> some View {
        switch store.verdicts[t.id] {
        case true?:
            Text("合ってる").font(.system(size: 10, weight: .semibold)).foregroundStyle(RenewalTokens.ink)
        case false?:
            Text("見直し中").font(.system(size: 10, weight: .semibold)).foregroundStyle(RenewalTokens.muted)
        case nil:
            Text(store.confidence(t) == 3 ? "わかった" : "答え合わせ待ち")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(store.confidence(t) == 3 ? RenewalTokens.ink : RenewalTokens.accentPink)
        }
    }

    private func lockedRow(_ t: PartnerTraitMock, more: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 13))
                .frame(width: 20)
                .foregroundStyle(RenewalTokens.controlBorder)
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title + (more > 0 ? " ほか\(more)つ" : ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                Text(t.unlockHint)
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer()
        }
        .padding(12)
        .background(RenewalTokens.raised.opacity(0.5))
    }

    // MARK: - ミッション

    private var missionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("理解度を上げるミッション")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let s = store.activeMissions.first?.stage {
                    Text("目安 \(PartnerMissionCatalog.stageDays[s] ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(RenewalTokens.muted)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(store.activeMissions.enumerated()), id: \.element.id) { i, m in
                    if i > 0 { Divider().padding(.leading, 44) }
                    PartnerMissionRow(mission: m, store: store)
                }
            }
            .renewalCard()
            Text("Sandbox: ミッションをタップすると1つ進みます")
                .font(.system(size: 10))
                .foregroundStyle(RenewalTokens.muted)
        }
    }
}

// MARK: - ミッションの行 (案A・案C で共用)

struct PartnerMissionRow: View {
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
                    Circle()
                        .stroke(done ? Color.clear : RenewalTokens.controlBorder, lineWidth: 1.5)
                        .background(Circle().fill(done ? RenewalTokens.ink : Color.clear))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: mission.icon)
                            .font(.system(size: 10))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.ink)
                        .strikethrough(done, color: RenewalTokens.muted)
                    if !mission.hint.isEmpty && !done {
                        Text(mission.hint)
                            .font(.system(size: 11))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(mission.points)%")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(done ? RenewalTokens.muted : RenewalTokens.ink)
                    if mission.target > 1 && !done {
                        Text("\(cur)/\(mission.target)")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(RenewalTokens.muted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mission.title)、\(done ? "クリア" : "\(cur)/\(mission.target)")、理解度プラス\(mission.points)%")
    }
}

// MARK: - 特徴の詳細シート (答え合わせ)

struct PartnerTraitDetailSheet: View {
    let trait: PartnerTraitMock
    @Bindable var store: PartnerProfileSandboxStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(trait.title, systemImage: trait.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                Spacer()
                Button("閉じる") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundStyle(RenewalTokens.ink)
            }
            HStack(spacing: 8) {
                Text(trait.value)
                    .font(.system(size: 22, weight: .bold))
                if !trait.swatches.isEmpty { PartnerProfileSwatches(colors: trait.swatches, size: 18) }
            }
            if let m = trait.meter {
                PartnerProfileMeter(left: m.left, right: m.right, value: m.value)
            }
            HStack(alignment: .top, spacing: 10) {
                PartnerIconImage(size: 32)
                Text(trait.detail)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("そう思った理由")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                ForEach(trait.evidence, id: \.self) { e in
                    Label(e, systemImage: "circle.fill")
                        .labelStyle(PartnerBulletLabelStyle())
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.ink)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                verdictButton("ちょっと違う", agree: false)
                verdictButton("合ってる", agree: true)
            }
        }
        .padding(20)
    }

    private func verdictButton(_ title: String, agree: Bool) -> some View {
        let selected = store.verdicts[trait.id] == agree
        return Button {
            Haptic.impact(.soft)
            store.verdict(trait, agree: agree)
            dismiss()
        } label: {
            Text(title)
        }
        .buttonStyle(RenewalPrimaryButtonStyle(filled: agree || selected))
    }
}

struct PartnerBulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon.font(.system(size: 4)).foregroundStyle(RenewalTokens.muted)
            configuration.title
        }
    }
}
