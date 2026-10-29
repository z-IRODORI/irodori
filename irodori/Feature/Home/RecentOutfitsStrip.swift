//
//  RecentOutfitsStrip.swift
//  irodori
//
//  ホームの3案の下に置く「最近のコーデ」。撮った記録を新しい順に横スクロールで見せる。
//  押すとコーデの詳細、長押しで削除。「選択」で複数を選んでまとめて削除。「カレンダーで見る」で一覧へ。
//  (明日の服を決めるときに「最近なにを着たか」が見えると、同じ組み合わせを避けやすい)
//

import Kingfisher
import SwiftUI

struct RecentOutfitsStrip: View {
    let coordinates: [RecentCoordinate]
    var onTap: (RecentCoordinate) -> Void
    var onDelete: (RecentCoordinate) -> Void
    /// 選んだコーデをまとめて削除 (確認は呼び出し側)
    var onDeleteMany: ([RecentCoordinate]) -> Void = { _ in }
    var onSeeAll: () -> Void

    @State private var selecting = false
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近のコーデ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Spacer()
                if selecting {
                    Button("キャンセル") {
                        Haptic.selection()
                        withAnimation(.easeInOut(duration: 0.2)) { selecting = false; selected = [] }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(minHeight: 44)
                } else {
                    Button("選択") {
                        Haptic.selection()
                        withAnimation(.easeInOut(duration: 0.2)) { selecting = true }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(minHeight: 44)
                    .padding(.trailing, 8)
                    Button {
                        Haptic.impact(.soft)
                        onSeeAll()
                    } label: {
                        HStack(spacing: 2) {
                            Text("カレンダーで見る")
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(coordinates.prefix(10), id: \.id) { c in
                        Button {
                            if selecting {
                                Haptic.selection()
                                if selected.contains(c.id) { selected.remove(c.id) } else { selected.insert(c.id) }
                            } else {
                                Haptic.impact(.soft)
                                onTap(c)
                            }
                        } label: {
                            card(c)
                                .overlay(alignment: .topTrailing) {
                                    if selecting { selectionMark(selected.contains(c.id)) }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selecting && selected.contains(c.id) ? .isSelected : [])
                        .contextMenu {
                            Button { onTap(c) } label: { Label("詳細を見る", systemImage: "doc.text.magnifyingglass") }
                            Button(role: .destructive) { onDelete(c) } label: { Label("このコーデを削除", systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }

            if selecting {
                Button {
                    Haptic.impact(.medium)
                    let picked = coordinates.filter { selected.contains($0.id) }
                    onDeleteMany(picked)
                } label: {
                    Text(selected.isEmpty ? "削除するコーデを選んでください" : "\(selected.count)件を削除")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected.isEmpty ? Color.gray.opacity(0.4) : Color.red, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selected.isEmpty)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
        }
        // 選んだコーデが消えたら (削除が終わったら) 選択モードを抜ける
        .onChange(of: coordinates.map(\.id)) { _, ids in
            let hadSelection = !selected.isEmpty
            selected.formIntersection(ids)
            if hadSelection && selected.isEmpty { selecting = false }
        }
    }

    private func selectionMark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(on ? RenewalTokens.ink : Color.white)
            .background(Circle().fill(on ? Color.white : Color.black.opacity(0.25)).padding(1))
            .padding(6)
            .accessibilityHidden(true)
    }

    private func card(_ c: RecentCoordinate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            KFImage(URL(string: c.displayImageURL))
                .placeholder { RenewalTokens.raised }
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RenewalTokens.border, lineWidth: 0.5))
            Text(Self.label(c.date))
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(RenewalTokens.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.label(c.date))のコーデ")
        .accessibilityHint("長押しで削除。「選択」でまとめて削除できます")
    }

    /// 「2026/10/12」「2026-10-12」→「10/12(日)」
    static func label(_ raw: String) -> String {
        let s = String(raw.prefix(10)).replacingOccurrences(of: "/", with: "-")
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ja_JP")
        out.dateFormat = "M/d(E)"
        return out.string(from: d)
    }
}
