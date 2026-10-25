//
//  DataOnboardingDesignC.swift
//  irodori - Sandbox
//
//  案C「見くらべ」: 1画面。つまみを動かすと、相棒が知っていることが増えて3案が「想像」→「手持ち」に変わる。
//  理由の説明より先に、変化を自分の指で確かめてもらう。
//  教え方は「服を教える」から下のシートで選ぶ。理解度の伸び (＋6% など) は小さく添えるだけ。
//

import SwiftUI

struct DataOnboardingDesignC: View {
    let state: DataOnbSandboxState
    @State private var amount: Double = 0
    @State private var showChannels = false

    /// 相棒画面のミッションの点数 (onboarding 6 / closet_5 6 / photo_1 5) と同じ
    private static let pct = [6, 12, 17]

    private var level: Int { Int(amount.rounded()) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("相棒に服を見せると、\n提案がこう変わります")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(RenewalTokens.ink)
                            .lineSpacing(2)
                        Text("つまみを右に動かしてみてください")
                            .font(.system(size: 13))
                            .foregroundStyle(RenewalTokens.muted)
                    }
                    compareCard
                    knowsCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            footer
        }
        .background(RenewalTokens.ground)
        .sheet(isPresented: $showChannels) {
            channelSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: 見くらべカード

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                PartnerIconImage(size: 24)
                Text(comment)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RenewalTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .frame(minHeight: 40, alignment: .leading)
            .animation(.easeInOut(duration: 0.25), value: level)

            DataOnbOutfitPreview(level: level)

            VStack(spacing: 6) {
                Slider(value: $amount, in: 0...2, step: 1) {
                    Text("相棒が知っていること")
                }
                .tint(RenewalTokens.ink)
                .onChange(of: level) { _, _ in Haptic.impact(.soft) }
                HStack {
                    Text("4つの答え")
                    Spacer()
                    Text("＋服を5点")
                    Spacer()
                    Text("＋着たコーデ")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RenewalTokens.muted)
            }
        }
        .padding(16)
        .partnerSoftCard()
    }

    private var comment: String {
        switch level {
        case 0: return "いまは想像で組んでいるよ。買い足しが多めかも"
        case 1: return "あなたの服を混ぜて組めた！明日すぐ着られるね"
        default: return "よく着る色や合わせ方まで汲んで組んだよ"
        }
    }

    // MARK: 相棒が知っていること

    private var knowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("相棒の理解度")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RenewalTokens.muted)
                Spacer()
                Text("\(Self.pct[level])%")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(RenewalTokens.ink)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: level)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(RenewalTokens.raised)
                    Capsule().fill(RenewalTokens.ink)
                        .frame(width: g.size.width * CGFloat(Self.pct[level]) / 100)
                        .animation(.spring(duration: 0.5), value: level)
                }
            }
            .frame(height: 6)
            PartnerFlowChips(spacing: 6) {
                chip("なりたい印象", on: true)
                chip("話し方", on: true)
                chip("持っている服", on: level >= 1)
                chip("よく着る色", on: level >= 1)
                chip("着回しのクセ", on: level >= 2)
                chip("季節の着方", on: level >= 2)
            }
            .animation(.easeInOut(duration: 0.25), value: level)
        }
        .padding(16)
        .partnerSoftCard()
        .accessibilityElement(children: .combine)
    }

    private func chip(_ text: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: on ? "checkmark" : "lock")
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(on ? PartnerHue.mint.ink : RenewalTokens.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(on ? PartnerHue.mint.wash : RenewalTokens.raised, in: Capsule())
    }

    // MARK: 下部

    private var footer: some View {
        VStack(spacing: 4) {
            if state.picked.isEmpty {
                // やんわり実績: ボタンの上にひとこと
                Text("教えるたびに、相棒画面の「ふたりの記録」が増えていきます")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
                    .padding(.bottom, 6)
                DataOnbPrimaryButton(title: "服を教える") { showChannels = true }
                DataOnbLaterButton { state.finished = true }
            } else {
                HStack(spacing: 10) {
                    DataOnbStampRow(picked: state.picked, size: 28)
                    Text("記録が\(state.picked.count)つ増えました")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RenewalTokens.ink)
                }
                .padding(.bottom, 8)
                DataOnbPrimaryButton(title: "ホームで3案を見る") { state.finished = true }
                DataOnbLaterButton(title: "ほかの方法でも教える") { showChannels = true }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(RenewalTokens.ground)
    }

    private var channelSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("どの方法で教える？")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(RenewalTokens.ink)
                .padding(.top, 28)
            VStack(spacing: 0) {
                ForEach(DataOnbChannel.allCases) { c in
                    DataOnbChannelRow(channel: c, recommended: c == .fullBody, done: state.picked.contains(c)) {
                        showChannels = false
                        state.pick(c)
                        withAnimation(.spring(duration: 0.6)) { amount = c == .standard ? 1 : 2 }
                    }
                    if c != DataOnbChannel.allCases.last {
                        Divider().overlay(RenewalTokens.rule).padding(.leading, 68)
                    }
                }
            }
            .background(RenewalTokens.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(RenewalTokens.ground)
    }
}
