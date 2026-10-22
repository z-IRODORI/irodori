//
//  PartnerProfileDesignD.swift
//  irodori - Sandbox
//
//  案D「相棒のふりかえりストーリー」
//  毎週、相棒が「この1週間のあなた」をストーリー (めくるスライド) にして届ける。
//  大きな数字と色で、自分でも知らなかったクセを驚きとして見せ、最後のスライドで答え合わせ。
//  画面には今週のストーリー (表紙) と、過去の週の背表紙が並ぶ。
//

import SwiftUI

struct PartnerProfileDesignD: View {
    @Bindable var store: PartnerProfileSandboxStore
    @Bindable var discoveries: PartnerDiscoveryState
    @State private var showMissions = false
    @State private var playing = false

    private var found: [PartnerDiscovery] { discoveries.discoveries(pct: store.pct) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PartnerUnderstandingStrip(store: store) { showMissions = true }
                thisWeek
                backIssues
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(RenewalTokens.ground)
        .sheet(isPresented: $showMissions) {
            PartnerAllMissionsSheet(store: store).presentationCornerRadius(28)
        }
        .fullScreenCover(isPresented: $playing) {
            PartnerStoryPlayer(discoveries: Array(found.prefix(3)), state: discoveries)
        }
    }

    // MARK: - 今週のストーリー (表紙)

    private var thisWeek: some View {
        Button {
            Haptic.impact(.medium)
            playing = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [PartnerHue.pink.ink, PartnerHue.lilac.ink, PartnerHue.sky.ink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                // 大きな数字の飾り
                Text("14")
                    .font(.system(size: 160, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 10, y: -20)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        PartnerIconImage(size: 34)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                        Text("10/16〜10/22")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text("今週のあなた、\n\(found.count)つ見つけたよ")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ForEach(found.prefix(4)) { d in
                            Text(d.rarity.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(d.hue.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.white))
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill").font(.system(size: 12))
                        Text("見る")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PartnerHue.lilac.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: PartnerHue.lilac.ink.opacity(0.3), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(found.isEmpty)
    }

    // MARK: - 過去の週

    private var backIssues: some View {
        let issues: [(String, String, PartnerHue)] = [
            ("10/9〜10/15", "白シャツは勝負の日担当", .sky),
            ("10/2〜10/8", "20℃で黒が増える", .mint),
            ("9/25〜10/1", "はじめての3案", .lemon),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("これまでのふりかえり")
                .font(.system(size: 16, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(issues, id: \.0) { week, title, hue in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(week)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(hue.ink)
                            Spacer(minLength: 0)
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(RenewalTokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(width: 128, height: 150, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(hue.wash))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - ストーリーの再生

struct PartnerStoryPlayer: View {
    let discoveries: [PartnerDiscovery]
    @Bindable var state: PartnerDiscoveryState
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private enum Slide {
        case intro
        case number
        case discovery(PartnerDiscovery)
        case ending
    }

    private var slides: [Slide] {
        [.intro, .number] + discoveries.map { .discovery($0) } + [.ending]
    }

    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        let slide = slides[index]
        ZStack(alignment: .top) {
            background(slide).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: index)

            // めくる (左 1/3 で戻る、右 2/3 で進む)。最後のスライドは答えるボタンがあるので止める
            if !isLast {
                HStack(spacing: 0) {
                    Color.clear.contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .onTapGesture { back() }
                    Color.clear.contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .onTapGesture { next() }
                    Color.clear.contentShape(Rectangle())
                        .frame(maxWidth: .infinity)
                        .onTapGesture { next() }
                }
            }

            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(slides.indices, id: \.self) { i in
                        Capsule().fill(.white.opacity(i <= index ? 0.95 : 0.3)).frame(height: 3)
                    }
                }
                HStack {
                    PartnerIconImage(size: 30).overlay(Circle().stroke(.white, lineWidth: 1.5))
                    Text("相棒のふりかえり")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                }
                Spacer(minLength: 0)
                content(slide)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    .allowsHitTesting(isLast)
                Spacer(minLength: 0)
                if !isLast {
                    Text("タップで次へ")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func next() {
        Haptic.impact(.soft)
        withAnimation(.spring(duration: 0.45)) { index = min(slides.count - 1, index + 1) }
    }

    private func back() {
        withAnimation(.spring(duration: 0.45)) { index = max(0, index - 1) }
    }

    private func background(_ s: Slide) -> LinearGradient {
        let pair: [Color]
        switch s {
        case .intro: pair = [PartnerHue.pink.ink, PartnerHue.lilac.ink]
        case .number: pair = [Color(white: 0.1), Color(white: 0.28)]
        case .discovery(let d): pair = [d.hue.ink, d.hue.ink.opacity(0.75)]
        case .ending: pair = [PartnerHue.sky.ink, PartnerHue.mint.ink]
        }
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func content(_ s: Slide) -> some View {
        switch s {
        case .intro:
            VStack(alignment: .leading, spacing: 14) {
                Text("10/16〜10/22")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("この1週間、\nずっと見てたよ")
                    .font(.system(size: 38, weight: .heavy))
                Text("あなた自身も気づいてないかもしれないこと、\(discoveries.count)つ見つけた")
                    .font(.system(size: 16, weight: .medium))
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .number:
            VStack(alignment: .leading, spacing: 10) {
                Text("黒を選んだ回数")
                    .font(.system(size: 18, weight: .bold))
                Text("14回")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("7日で14回。毎日どこかに黒がいた。\nあなたにとって黒は「ふつう」じゃなくて「安心」なんだと思う")
                    .font(.system(size: 16, weight: .medium))
                    .lineSpacing(4)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .discovery(let d):
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: d.icon)
                    Text(d.rarity == .normal ? "発見" : "\(d.rarity.rawValue)な発見")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.2)))
                Text(d.headline)
                    .font(.system(size: 30, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                Text(d.body)
                    .font(.system(size: 15, weight: .medium))
                    .lineSpacing(4)
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
                PartnerDiscoveryVizView(viz: d.viz, hue: d.hue)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ending:
            VStack(alignment: .leading, spacing: 16) {
                Text("ひとつだけ聞かせて")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                if let d = discoveries.first {
                    PartnerDigView(discovery: d, state: state)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(d.hue.wash))
                }
                Text("答えると、来週の3案が変わるよ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Button {
                    back()
                } label: {
                    Text("前のスライドに戻る")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
