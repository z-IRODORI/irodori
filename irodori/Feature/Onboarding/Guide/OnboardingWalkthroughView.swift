//
//  OnboardingWalkthroughView.swift
//  irodori
//
//  初回起動のウォークスルー: 4つの質問の前に IRODORI と相棒を3枚で伝える
//  (PartnerOnboardingFlowView の初回だけ、相棒の紹介カードの代わりに出す)。
//  - 3枚まで。1枚に伝えることは1つ、本文は2行まで。どのページからでもスキップできる
//  - 上半分は写真と相棒の絵で「見てわかる」場面にする (アプリに同梱のコーデ写真・相棒の絵を使う)
//      1枚目: 3つのコーデ写真が扇形に広がり、相棒が「この3つから選んで」
//      2枚目: 相棒たちが並び、スポットライトが順に当たる (4つの質問で決まる)
//      3枚目: 写真を見せると相棒に届き、理解度が上がって「ふたりの記録」にスタンプが押される
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
              body: "4つの質問で、あなたに合う相棒が生まれます。好みや着た服を覚えて育っていきます。"),
        .init(hue: .peach, eyebrow: "育てかた",
              title: "見せるほど、\nあなたの服で組める",
              body: "写真や服を教えると提案の精度が上がり、ふたりの記録も増えていきます。"),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i], index: i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(alignment: .top) {
            // ページの色を上からうっすら敷く (切り替えでなめらかに変わる)
            LinearGradient(colors: [pages[page].hue.wash, RenewalTokens.surface],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: page)
        }
        .background(RenewalTokens.surface.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if !isLast {
                Button("スキップ") {
                    Haptic.impact(.soft)
                    onFinish()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.trailing, 12)
            }
        }
    }

    // MARK: ページ

    private func pageView(_ p: Page, index: Int) -> some View {
        VStack(spacing: 0) {
            Group {
                switch index {
                case 0: WalkthroughPicksScene(active: page == 0)
                case 1: WalkthroughPartnersScene(active: page == 1, hue: p.hue)
                default: WalkthroughGrowScene(active: page == 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 400)
            .padding(.top, 36)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(p.eyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(p.hue.ink)
                Text(p.title)
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(p.body)
                    .font(.system(size: 15))
                    .foregroundStyle(RenewalTokens.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
        }
    }

    // MARK: 下部

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? pages[page].hue.ink : RenewalTokens.controlBorder)
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
                Text(isLast ? "4つの質問に答えて相棒に会う" : "つぎへ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RenewalTokens.primaryFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint(isLast ? "約30秒" : "")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}

// MARK: - 部品

/// 写真カード (白い縁・影)。写真はアプリ同梱の見本コーデ
private struct WalkthroughPhotoCard: View {
    let name: String
    var width: CGFloat = 132
    var label: String? = nil

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: width * 4 / 3)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(4)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RenewalTokens.primaryFill, in: Capsule())
                        .padding(10)
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
    }
}

/// 相棒の吹き出し (アイコン + しっぽ付き)
private struct WalkthroughBubble: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .background(Color.white, in: Circle())
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white, in: UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16,
                    style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }
}

// MARK: - 1枚目: 3つのコーデから選ぶ

private struct WalkthroughPicksScene: View {
    let active: Bool
    @State private var spread = false

    var body: some View {
        ZStack {
            WalkthroughPhotoCard(name: "coordinate-2", width: 118, label: "A")
                .rotationEffect(.degrees(spread ? -10 : 0))
                .offset(x: spread ? -104 : 0, y: spread ? 22 : 0)
            WalkthroughPhotoCard(name: "coordinate-7", width: 118, label: "C")
                .rotationEffect(.degrees(spread ? 10 : 0))
                .offset(x: spread ? 104 : 0, y: spread ? 22 : 0)
            WalkthroughPhotoCard(name: "coordinate-5", width: 140, label: "B")
                .offset(y: spread ? -6 : 0)
                .scaleEffect(spread ? 1 : 0.94)

            // 明日の天気
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill").foregroundStyle(Color.orange)
                Text("明日 18° / 12°")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            .offset(y: -168)
            .opacity(spread ? 1 : 0)

            WalkthroughBubble(icon: "クリーン・スタンダード_icon", text: "明日はこの3つから選んでね")
                .offset(x: -10, y: 166)
                .opacity(spread ? 1 : 0)
                .offset(y: spread ? 0 : 12)
        }
        .onChange(of: active, initial: true) { _, on in
            if on {
                spread = false
                withAnimation(.spring(duration: 0.7, bounce: 0.3).delay(0.15)) { spread = true }
            }
        }
    }
}

// MARK: - 2枚目: 相棒たち (4つの質問で、どの相棒になるかが決まる)

private struct WalkthroughPartnersScene: View {
    let active: Bool
    let hue: PartnerHue
    @State private var spotlight = 2
    @State private var appeared = false

    private let cast = ["トレンド・エディター", "アヴァンギャルド・スター", "クリーン・スタンダード", "ロイヤル・クラシック", "アクティブ・クリエイター"]

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("16タイプの相棒から、あなたの相棒が生まれる")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(hue.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white, in: Capsule())
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

            // 足もとに影を置いて並べ、スポットライトの当たった相棒だけ大きく色をつける
            HStack(alignment: .bottom, spacing: -18) {
                ForEach(cast.indices, id: \.self) { i in
                    let on = i == spotlight
                    VStack(spacing: -8) {
                        Image(cast[i])
                            .resizable()
                            .scaledToFit()
                            .frame(height: on ? 210 : 145)
                            .saturation(on ? 1 : 0.1)
                            .opacity(on ? 1 : 0.5)
                        Ellipse()
                            .fill(on ? hue.ink.opacity(0.28) : Color.black.opacity(0.06))
                            .frame(width: on ? 90 : 56, height: on ? 18 : 10)
                            .blur(radius: on ? 3 : 1)
                    }
                    .zIndex(on ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(duration: 0.6).delay(Double(i) * 0.06), value: appeared)
                    .animation(.spring(duration: 0.45, bounce: 0.35), value: spotlight)
                }
            }
            .frame(height: 270)

            Text("4つの質問で決まります")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RenewalTokens.muted)
        }
        .task(id: active) {
            guard active else { appeared = false; return }
            appeared = true
            // 順にスポットライトを当てる (ページを見ている間だけ)
            var i = spotlight
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.1))
                i = (i + 1) % cast.count
                spotlight = i
            }
        }
    }
}

// MARK: - 3枚目: 見せるほど相棒がわかる・ふたりの記録

private struct WalkthroughGrowScene: View {
    let active: Bool
    @State private var sent = 0
    @State private var flying: Int? = nil

    private let photos = ["coordinate-1", "coordinate-10", "coordinate-4"]
    private let stamps: [(icon: String, hue: PartnerHue)] = [("photo.on.rectangle.angled", .lilac), ("tshirt", .mint), ("camera", .peach)]
    private var pct: Int { [6, 24, 41, 58][min(sent, 3)] }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // 左: 見せる写真 (まだ見せていないものが重なっている)
                ForEach(photos.indices.reversed(), id: \.self) { i in
                    let isSent = i < sent
                    let isFlying = flying == i
                    // 見せた写真は相棒のそばに小さく重なって残る (受け取った、が見てわかるように)
                    WalkthroughPhotoCard(name: photos[i], width: 84)
                        .rotationEffect(.degrees(isSent ? Double(i) * 9 - 9 : (isFlying ? 0 : Double(i) * 6 - 6)))
                        .scaleEffect(isSent ? 0.55 : (isFlying ? 0.75 : 1))
                        .offset(x: isSent ? 2 + CGFloat(i) * 14 : (isFlying ? -20 : -92 + CGFloat(i) * 8),
                                y: isSent ? 70 - CGFloat(i) * 4 : (isFlying ? 20 : CGFloat(i) * 4))
                        .zIndex(isFlying ? 2 : 0)
                }

                // 右: 相棒
                Image("クリーン・スタンダード")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)
                    .offset(x: 84, y: 6)
                    .scaleEffect(flying != nil ? 1.04 : 1, anchor: .bottom)

                WalkthroughBubble(icon: "クリーン・スタンダード_icon",
                                  text: sent == 0 ? "どんな服を着てるの？" : "見せてくれてありがとう！")
                    .scaleEffect(0.92)
                    .offset(x: -6, y: -128)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: sent == 0)
            }
            .frame(height: 280)

            // 理解度とふたりの記録
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("相棒の理解度")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.muted)
                    Spacer()
                    Text("\(pct)%")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(RenewalTokens.ink)
                        .contentTransition(.numericText())
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(RenewalTokens.raised)
                        Capsule()
                            .fill(LinearGradient(colors: [PartnerHue.peach.ink, RenewalTokens.accentPink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * CGFloat(pct) / 100)
                    }
                }
                .frame(height: 7)
                HStack(spacing: 8) {
                    ForEach(stamps.indices, id: \.self) { i in stamp(i) }
                    Text("ふたりの記録")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RenewalTokens.ink)
                        .padding(.leading, 2)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .padding(.horizontal, 28)
            .animation(.spring(duration: 0.5), value: sent)
        }
        .task(id: active) {
            guard active else { sent = 0; flying = nil; return }
            sent = 0
            for i in photos.indices {
                try? await Task.sleep(for: .seconds(i == 0 ? 0.7 : 0.6))
                withAnimation(.easeIn(duration: 0.45)) { flying = i }
                try? await Task.sleep(for: .seconds(0.45))
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
                    flying = nil
                    sent = i + 1
                }
            }
        }
    }

    private func stamp(_ i: Int) -> some View {
        let on = i < sent
        let s = stamps[i]
        return ZStack {
            Circle().fill(on ? s.hue.wash : Color.clear)
            Circle().strokeBorder(on ? s.hue.ink.opacity(0.5) : RenewalTokens.controlBorder,
                                  style: StrokeStyle(lineWidth: 1.2, dash: on ? [] : [3, 3]))
            Image(systemName: on ? s.icon : "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? s.hue.ink : RenewalTokens.controlBorder)
        }
        .frame(width: 30, height: 30)
        .scaleEffect(on ? 1 : 0.9)
        .rotationEffect(.degrees(on ? -8 : 0))
    }
}

#Preview {
    OnboardingWalkthroughView(onFinish: {})
}
