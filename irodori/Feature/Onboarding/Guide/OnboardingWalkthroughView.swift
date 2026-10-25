//
//  OnboardingWalkthroughView.swift
//  irodori
//
//  初回起動のウォークスルー: 4つの質問の前に IRODORI と相棒を3枚で伝える
//  (PartnerOnboardingFlowView の初回だけ、相棒の紹介カードの代わりに出す)。
//  - 3枚まで。1枚に伝えることは1つ、本文は2行まで
//  - どのページでも右上から「スキップ」できる (4つの質問へ進む)
//  - 下にページの点と「つぎへ」。最後のページだけ「4つの質問に答える」
//  - 3枚目で「服やコーデを教えるほど提案が良くなる」「ふたりの記録が増える」をやんわり伝える
//

import SwiftUI

struct OnboardingWalkthroughView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let hue: PartnerHue
        let eyebrow: String
        let title: String
        let body: String
    }

    private let pages: [Page] = [
        .init(hue: .sky, eyebrow: "IRODORI",
              title: "次に着る服を、\n3案から選ぶだけ",
              body: "天気と手持ちの服から、毎日3つのコーデを用意します。"),
        .init(hue: .lilac, eyebrow: "相棒",
              title: "選ぶのは、\nあなた専属の「相棒」",
              body: "好みや着た服を覚えて、だんだんあなた好みの3案になっていきます。"),
        .init(hue: .mint, eyebrow: "育てかた",
              title: "教えるほど、\nあなたの服で組める",
              body: "服やコーデを教えると提案の精度が上がり、ふたりの記録も増えていきます。"),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("スキップ") {
                        Haptic.impact(.soft)
                        onFinish()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RenewalTokens.muted)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 12)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i], index: i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(RenewalTokens.ground.ignoresSafeArea())
    }

    // MARK: ページ

    private func pageView(_ p: Page, index: Int) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(p.hue.wash)
                visual(index, hue: p.hue)
            }
            .frame(height: 300)
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text(p.eyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(p.hue.ink)
                Text(p.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text(p.body)
                    .font(.system(size: 15))
                    .foregroundStyle(RenewalTokens.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 28)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func visual(_ index: Int, hue: PartnerHue) -> some View {
        switch index {
        case 0: WalkthroughThreePicks()
        case 1: WalkthroughPartnerOrbit(hue: hue)
        default: WalkthroughGrowing(active: page == 2)
        }
    }

    // MARK: 下部

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? RenewalTokens.ink : RenewalTokens.controlBorder)
                        .frame(width: i == page ? 20 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.3), value: page)
            .accessibilityElement()
            .accessibilityLabel("\(pages.count)ページ中\(page + 1)ページ目")

            Button {
                Haptic.impact(.medium)
                if isLast {
                    onFinish()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                }
            } label: {
                Text(isLast ? "4つの質問に答える（約30秒）" : "つぎへ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RenewalTokens.primaryFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

// MARK: - 見本の3案 (色ブロックでトップス・ボトムス・靴。実在の商品は出さない)

private struct WalkthroughOutfitSample: View {
    /// 0: 想像 (点線) / 1: 一部手持ち / 2: すべて手持ち
    let level: Int

    private static let palettes: [[Color]] = [
        [Color(white: 0.96), Color(red: 0.20, green: 0.27, blue: 0.40), Color(white: 0.15)],
        [Color(red: 0.93, green: 0.90, blue: 0.84), Color(red: 0.38, green: 0.33, blue: 0.27), Color(white: 0.92)],
        [Color(red: 0.12, green: 0.12, blue: 0.13), Color(red: 0.62, green: 0.62, blue: 0.60), Color(white: 0.15)],
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in column(i) }
        }
        .animation(.spring(duration: 0.5), value: level)
    }

    private func owned(_ index: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return index == 0 ? 2 : 1
        default: return 3
        }
    }

    private func column(_ index: Int) -> some View {
        let count = owned(index)
        let heights: [CGFloat] = [44, 50, 16]
        return VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { p in
                WalkthroughOutfitPart(color: Self.palettes[index][p], owned: p < count)
                    .frame(height: heights[p])
            }
            HStack(spacing: 3) {
                Image(systemName: count == 3 ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 9, weight: .semibold))
                Text(count == 3 ? "手持ち" : count == 0 ? "想像" : "一部手持ち")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(count == 3 ? RenewalTokens.ink : RenewalTokens.muted)
            .padding(.top, 2)
            .transaction { $0.animation = nil }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(RenewalTokens.border))
    }
}

private struct WalkthroughOutfitPart: View {
    let color: Color
    let owned: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        if owned {
            shape.fill(color).overlay(shape.strokeBorder(Color.black.opacity(0.08)))
        } else {
            shape.strokeBorder(RenewalTokens.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .overlay {
                    Image(systemName: "questionmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RenewalTokens.controlBorder)
                }
        }
    }
}

// MARK: - 1枚目: 3案

private struct WalkthroughThreePicks: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(Color.orange)
                Text("明日  18° / 12°")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RenewalTokens.surface, in: Capsule())

            WalkthroughOutfitSample(level: 2)
                .padding(.horizontal, 28)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 2枚目: 相棒 (まだ誕生前なので特徴のない姿)

private struct WalkthroughPartnerOrbit: View {
    let hue: PartnerHue
    @State private var sway = false

    private let chips = ["好きな色", "着回し", "気温", "似合う形"]

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(hue.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 220, height: 220)
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(RenewalTokens.surface)
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(hue.ink)
                }
                .frame(width: 96, height: 96)
                .shadow(color: hue.ink.opacity(0.15), radius: 12, y: 4)
                Text("4つの質問で誕生します")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(hue.ink)
            }
            ForEach(chips.indices, id: \.self) { i in
                let angle = Angle.degrees(Double(i) * 90 - 45 + (sway ? 8 : -8))
                Text(chips[i])
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hue.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RenewalTokens.surface, in: Capsule())
                    .offset(x: cos(angle.radians) * 110, y: sin(angle.radians) * 110)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { sway = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 3枚目: 教えるほど手持ちに・ふたりの記録

private struct WalkthroughGrowing: View {
    let active: Bool
    @State private var level = 0
    @State private var stamps = 0

    private let stampIcons: [(icon: String, hue: PartnerHue)] = [
        ("photo.on.rectangle.angled", .lilac), ("tshirt", .mint), ("camera", .peach),
    ]

    var body: some View {
        VStack(spacing: 18) {
            WalkthroughOutfitSample(level: level)
                .padding(.horizontal, 28)
            HStack(spacing: 8) {
                ForEach(stampIcons.indices, id: \.self) { i in stamp(i) }
                Text("ふたりの記録")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PartnerHue.mint.ink)
                    .padding(.leading, 2)
            }
        }
        .task(id: active) {
            guard active else { level = 0; stamps = 0; return }
            for i in 1...3 {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                    level = min(2, i)
                    stamps = i
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func stamp(_ i: Int) -> some View {
        let on = i < stamps
        let s = stampIcons[i]
        return ZStack {
            Circle().fill(on ? s.hue.wash : Color.clear)
            Circle().strokeBorder(on ? s.hue.ink.opacity(0.5) : RenewalTokens.controlBorder,
                                  style: StrokeStyle(lineWidth: 1.2, dash: on ? [] : [3, 3]))
            Image(systemName: on ? s.icon : "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? s.hue.ink : RenewalTokens.controlBorder)
        }
        .frame(width: 30, height: 30)
        .scaleEffect(on ? 1 : 0.92)
    }
}

#Preview {
    OnboardingWalkthroughView(onFinish: {})
}
