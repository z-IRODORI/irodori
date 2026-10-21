//
//  PartnerGrowthCard.swift
//  irodori
//
//  ホーム下部:「相棒があなたのことを知りたがっています」。
//  相棒が今どれくらいあなたを知っているか (覚えた服の数) と、
//  もっと知ってもらうための3つの導線を、相棒からのお願いとして並べる。
//  Lv・EXP などのゲーム用語は使わない。
//

import SwiftUI

struct PartnerGrowthCard: View {
    let typeName: String
    let closetCount: Int
    /// 相棒の理解度 (%)。相棒画面・見比べと同じ値 (api/partner)。読み込み前は nil
    var understandingPct: Int? = nil
    /// 撮影から切り抜いた (粗い) 服の数。あれば「きれいな画像に」と相棒からお願いする
    var roughImageCount: Int = 0
    var onTapFullBody: () -> Void
    var onTapStandardItems: () -> Void
    var onTapTasteVote: () -> Void
    var onTapCleanImages: () -> Void = {}

    /// 提案の幅が広がる目安 (トップス・ボトムス・靴などが一通りそろう数)
    private let comfortableCount = 15

    private var progress: Double {
        if let pct = understandingPct { return min(1, Double(pct) / 100) }
        return min(1, Double(closetCount) / Double(comfortableCount))
    }

    /// 目安の服の数を超えたら、次の目標 (好み・全身写真) に話題を移す
    private var statusText: String {
        if closetCount == 0 { return "まだ手持ちの服を知らないんだ" }
        if closetCount < comfortableCount {
            return "手持ちの服を\(closetCount)点覚えたよ。あと\(comfortableCount - closetCount)点で提案の幅がぐっと広がる"
        }
        return "手持ちの服は\(closetCount)点覚えたよ。次は好きなコーデを教えてくれたら、もっと合わせられる"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RenewalPartnerAvatar(typeName: typeName, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text("相棒があなたのことを知りたがっています")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RenewalTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 相棒の理解度 (相棒画面と同じ値)。届く前は覚えた服の数で目安を出す
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(RenewalTokens.border)
                        Capsule().fill(RenewalTokens.ink)
                            .frame(width: max(6, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
                HStack {
                    if let pct = understandingPct {
                        Text("相棒の理解度 \(pct)%")
                    } else {
                        Text("覚えた服 \(closetCount)点")
                    }
                    Spacer()
                    Text("覚えた服 \(closetCount)点")
                        .opacity(understandingPct == nil ? 0 : 1)
                }
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(RenewalTokens.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(understandingPct.map { "相棒の理解度は\($0)%。覚えた服は\(closetCount)点" } ?? "相棒が覚えた服は\(closetCount)点")

            VStack(spacing: 0) {
                ask(icon: "person.crop.rectangle.stack", title: "あなたの全身写真を見せて",
                    detail: "写真フォルダからAIが自動で探すよ", action: onTapFullBody)
                Divider().overlay(RenewalTokens.rule).padding(.leading, 52)
                ask(icon: "tshirt", title: "持っている服を教えて",
                    detail: "定番アイテムを選ぶだけ。写真はいらないよ", action: onTapStandardItems)
                Divider().overlay(RenewalTokens.rule).padding(.leading, 52)
                ask(icon: "hand.thumbsup", title: "好きなコーデを教えて",
                    detail: "2つを見比べて選ぶだけ", action: onTapTasteVote)
                if roughImageCount > 0 {
                    Divider().overlay(RenewalTokens.rule).padding(.leading, 52)
                    ask(icon: "sparkles", title: "服の写真をきれいにしよう",
                        detail: "撮影から切り抜いた\(roughImageCount)点を、商品画像に差し替えられるよ", action: onTapCleanImages)
                }
            }
            .background(RenewalTokens.ground)
            .clipShape(RoundedRectangle(cornerRadius: RenewalTokens.cardRadius))
        }
        .padding(16)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func ask(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(RenewalTokens.ink)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(RenewalTokens.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
