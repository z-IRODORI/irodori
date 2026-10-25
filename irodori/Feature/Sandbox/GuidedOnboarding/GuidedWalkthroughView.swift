//
//  GuidedWalkthroughView.swift
//  irodori - Sandbox
//
//  ウォークスルー型: 初回起動時 (4つの質問の前) に IRODORI と相棒を3枚で伝える。
//  いまの「相棒の紹介カード」1枚の置き換え。
//  - 3枚まで。1枚に伝えることは1つ、本文は2行まで
//  - どのページでも右上から「スキップ」できる (4つの質問へ進む)
//  - 下にページの点と「つぎへ」。最後のページだけ「4つの質問に答える」
//

import SwiftUI

struct GuidedWalkthroughView: View {
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
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
        .background(RenewalTokens.ground)
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

            DataOnbPrimaryButton(title: page < pages.count - 1 ? "つぎへ" : "4つの質問に答える（約30秒）") {
                if page < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                } else {
                    onFinish()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
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

            DataOnbOutfitPreview(level: 2)
                .padding(.horizontal, 28)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 2枚目: 相棒 (まだ誕生前なので特徴のない姿)

private struct WalkthroughPartnerOrbit: View {
    let hue: PartnerHue
    @State private var spin = false

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
                let angle = Angle.degrees(Double(i) * 90 - 45 + (spin ? 8 : -8))
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
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { spin = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 3枚目: 教えるほど手持ちに

private struct WalkthroughGrowing: View {
    let active: Bool
    @State private var level = 0
    @State private var stamps: [DataOnbChannel] = []

    var body: some View {
        VStack(spacing: 18) {
            DataOnbOutfitPreview(level: level)
                .padding(.horizontal, 28)
            HStack(spacing: 10) {
                DataOnbStampRow(picked: stamps, size: 30)
                Text("ふたりの記録")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PartnerHue.mint.ink)
            }
        }
        .task(id: active) {
            guard active else { level = 0; stamps = []; return }
            let order: [DataOnbChannel] = [.fullBody, .standard, .camera]
            for i in 0..<3 {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.spring(duration: 0.5)) {
                    level = min(2, i + 1)
                    stamps.append(order[i])
                }
            }
        }
        .accessibilityHidden(true)
    }
}
