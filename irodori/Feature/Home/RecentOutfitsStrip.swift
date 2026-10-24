//
//  RecentOutfitsStrip.swift
//  irodori
//
//  ホームの3案の下に置く「最近のコーデ」。撮った記録を新しい順に横スクロールで見せる。
//  押すとコーデの詳細、長押しで削除。「カレンダーで見る」で一覧へ。
//  (明日の服を決めるときに「最近なにを着たか」が見えると、同じ組み合わせを避けやすい)
//

import Kingfisher
import SwiftUI

struct RecentOutfitsStrip: View {
    let coordinates: [RecentCoordinate]
    var onTap: (RecentCoordinate) -> Void
    var onDelete: (RecentCoordinate) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近のコーデ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Spacer()
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
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(coordinates.prefix(10), id: \.id) { c in
                        Button {
                            Haptic.impact(.soft)
                            onTap(c)
                        } label: {
                            card(c)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { onTap(c) } label: { Label("詳細を見る", systemImage: "doc.text.magnifyingglass") }
                            Button(role: .destructive) { onDelete(c) } label: { Label("このコーデを削除", systemImage: "trash") }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
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
        .accessibilityHint("長押しで削除できます")
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
