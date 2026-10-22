//
//  PartnerProfileShared.swift
//  irodori - Sandbox
//
//  相棒画面の改善案 (A〜D) で共用する、ミッションの行と実績シート。
//

import SwiftUI

extension View {
    /// 罫線なしの白カード (IRODORI の白カード + うすい影)
    func partnerSoftCard(_ radius: CGFloat = 18) -> some View {
        background(RenewalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
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
                            .partnerSoftCard()
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

