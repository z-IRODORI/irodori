//
//  BrandMatchDesignA.swift
//  irodori - Sandbox
//
//  案 A「ロゴ一覧」: ZOZOTOWN のブランド一覧のように、正方形のロゴを主役に並べる。
//  - 見出し: 「モテ・プランナーのあなたに合う 10 ブランド」と、どう選んだかの 1 行 (相棒の顔つき)
//  - タブ: すべて / いちばん合う / 少し背伸び / 新しい出会い で絞り込む
//  - 表示: リスト (順位・ロゴ・名前・テイストと価格・合う理由・♡) と タイル (3 列) を切り替え
//  行やタイルをタップすると詳細シート。♡ はその場で「好き」にできる。
//

import SwiftUI

struct BrandMatchDesignA: View {
    @Bindable var store: BMSandboxStore
    @State private var opened: BMPick?
    @State private var filter: BMSlot?          // nil = すべて
    @State private var grid = false

    private var persona: BMPersona { store.persona }
    private var ranked: [(rank: Int, pick: BMPick)] { persona.picks.enumerated().map { ($0.offset + 1, $0.element) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                toolbar
                if let filter {
                    section(filter, rows: ranked.filter { $0.pick.slot == filter })
                } else {
                    ForEach(BMSlot.allCases) { slot in
                        let rows = ranked.filter { $0.pick.slot == slot }
                        if !rows.isEmpty { section(slot, rows: rows) }
                    }
                }
                Text("ブランドのロゴ以外の画像には「運営」「デザイナー」などを添えています。IRODORI とブランドの提携はありません。")
                    .font(.system(size: 11))
                    .foregroundStyle(BMTokens.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(BMTokens.ground)
        .sheet(item: $opened) { BMDetailSheet(store: store, pick: $0) }
    }

    // MARK: 見出し (何の一覧か + どう選んだか)

    /// ホームの相棒カードと同じ組み方 (白い面 + 相棒 40pt + 15pt の見出し + 12pt の補足)
    private var header: some View {
        HStack(spacing: 12) {
            BMPartnerIcon(persona: persona, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("あなたに合う 10 ブランド")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BMTokens.ink)
                Text("好みとクローゼットの服から選んだよ")
                    .font(.system(size: 12))
                    .foregroundStyle(BMTokens.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .bmCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: タブ (絞り込み) と 表示の切り替え

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    tab(nil, title: "すべて", count: persona.picks.count)
                    ForEach(BMSlot.allCases) { s in tab(s, title: s.title, count: persona.picks(in: s).count) }
                }
            }
            HStack {
                Text("おすすめ順・\(filter.map { persona.picks(in: $0).count } ?? persona.picks.count) ブランド")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(BMTokens.muted)
                Spacer()
                HStack(spacing: 0) {
                    viewButton("list.bullet", on: !grid, label: "リストで表示") { grid = false }
                    viewButton("square.grid.3x3", on: grid, label: "タイルで表示") { grid = true }
                }
                .clipShape(RoundedRectangle(cornerRadius: BMTokens.controlRadius))
                .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
            }
        }
    }

    private func tab(_ slot: BMSlot?, title: String, count: Int) -> some View {
        let on = filter == slot
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { filter = slot }
            Haptic.selection()
        } label: {
            HStack(spacing: 3) {
                Text(title).font(.system(size: 12, weight: on ? .semibold : .regular))
                Text("\(count)").font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(on ? BMTokens.surface.opacity(0.8) : BMTokens.muted)
            }
            .foregroundStyle(on ? BMTokens.surface : BMTokens.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(on ? BMTokens.primary : BMTokens.surface, in: Capsule())
            .overlay(Capsule().stroke(on ? .clear : BMTokens.control, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func viewButton(_ icon: String, on: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(on ? BMTokens.ink : BMTokens.faint)
                .frame(width: 36, height: 30)
                .background(on ? BMTokens.raised : BMTokens.surface)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 一覧

    private func section(_ slot: BMSlot, rows: [(rank: Int, pick: BMPick)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BMSectionHeader(title: slot.title, count: rows.count, note: slot.subtitle)
            if grid {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
                          spacing: 16) {
                    ForEach(rows, id: \.pick.id) { r in
                        BMBrandTile(pick: r.pick, rank: r.rank, reaction: store.reaction(r.pick.brandID)) {
                            store.toggle(.like, for: r.pick.brandID)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { opened = r.pick }
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.pick.id) { i, r in
                        if i > 0 { BMRule(leading: 106) }
                        BMBrandRow(pick: r.pick, rank: r.rank, reaction: store.reaction(r.pick.brandID),
                                   onLike: { store.toggle(.like, for: r.pick.brandID) })
                            .contentShape(Rectangle())
                            .onTapGesture { opened = r.pick }
                            // ♡ を別に押せるよう、行はまとめずに「くわしく見る」の操作を足す
                            .accessibilityElement(children: .contain)
                            .accessibilityAction(named: Text("くわしく見る")) { opened = r.pick }
                    }
                }
                .bmCard()
            }
        }
    }
}
