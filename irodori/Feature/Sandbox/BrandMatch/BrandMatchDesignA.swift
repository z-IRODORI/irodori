//
//  BrandMatchDesignA.swift
//  irodori - Sandbox
//
//  案 A「3 枠リスト」: ど真ん中 → ちょっと背伸び → はじめまして の順に、ロゴつきの行で並べる。
//  1 行は「ロゴ枠 + 名前 + 価格と合うところ」だけ。理由・特徴・歴史は行をタップした詳細シートへ。
//

import SwiftUI

struct BrandMatchDesignA: View {
    @Bindable var store: BMSandboxStore
    @State private var opened: BMPick?

    private var persona: BMPersona { store.persona }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                partnerCard
                ForEach(BMSlot.allCases) { slot in
                    let picks = persona.picks(in: slot)
                    if !picks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            BMSectionHeader(title: slot.title, count: picks.count, note: slot.subtitle)
                            VStack(spacing: 0) {
                                ForEach(Array(picks.enumerated()), id: \.element.id) { i, p in
                                    if i > 0 { BMRule(leading: 92) }
                                    Button { opened = p } label: {
                                        BMBrandRow(pick: p, reaction: store.reaction(p.brandID))
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .bmCard()
                        }
                    }
                }
                Text("IRODORI とブランドの提携はありません。")
                    .font(.system(size: 12))
                    .foregroundStyle(BMTokens.faint)
            }
            .padding(16)
        }
        .background(BMTokens.ground)
        .sheet(item: $opened) { BMDetailSheet(store: store, pick: $0) }
    }

    /// 相棒のひとことを 1 枚に (相棒の顔 + 一言)。高さを抑える
    private var partnerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            BMPartnerIcon(persona: persona, size: 36)
            Text(persona.partnerLine)
                .font(.system(size: 14))
                .foregroundStyle(BMTokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .bmCard()
    }
}
