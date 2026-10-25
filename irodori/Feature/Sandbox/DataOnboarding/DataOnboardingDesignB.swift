//
//  DataOnboardingDesignB.swift
//  irodori - Sandbox
//
//  案B「相棒とおしゃべり」: 相棒が話しかけ、ユーザーは返事のボタンを押して進む。
//  知りたい順 (どうなるの？ → どうやるの？) に答えが返ってくるので、説明を読まされている感じが少ない。
//  教えると、相棒が「ふたりの記録」にスタンプを押すところを会話の中で見せる。
//

import SwiftUI

struct DataOnboardingDesignB: View {
    let state: DataOnbSandboxState

    /// 会話の進み具合
    private enum Beat: Int, Comparable {
        case hello, askWhy, answerWhy, askHow, answerHow, thanks
        static func < (a: Beat, b: Beat) -> Bool { a.rawValue < b.rawValue }
    }

    @State private var beat: Beat = .hello
    @State private var typing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        transcript
                        if typing { typingDots }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                // 新しい発言が並んでから下端へ送る (すぐ送ると出現前の高さで止まる)
                .onChange(of: beat) { _, _ in scrollToEnd(proxy) }
                .onChange(of: typing) { _, _ in scrollToEnd(proxy) }
            }
            replyBar
        }
        .background(RenewalTokens.ground)
        .task { await say(.askWhy, after: 1.6) }
        .onChange(of: state.picked.count) { old, new in
            guard new > old, beat == .answerHow else { return }
            Task { await say(.thanks, after: 0.9) }
        }
        .onChange(of: state.picked.isEmpty) { _, empty in
            // Sandbox の「リセット」で最初から
            if empty { beat = .hello; Task { await say(.askWhy, after: 1.6) } }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    // MARK: 会話

    @ViewBuilder
    private var transcript: some View {
        DataOnbBubble(text: "誕生させてくれてありがとう！\n4つの答えで、あなたの好みはだいたいわかったよ。")
        DataOnbBubble(text: "でもね、あなたがどんな服を持っているかは、まだ知らないんだ。", showsIcon: false)

        if beat >= .answerWhy {
            userBubble("服を教えたらどうなるの？")
            DataOnbBubble(text: "あなたのクローゼットの服で3案を組めるようになるよ。\n「買い足さなくても明日着られる」案が増えるんだ。")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            DataOnbGrowingPreview()
                .padding(.leading, 40)
                .padding(.trailing, 32)
                .transition(.opacity)
        }
        if beat >= .answerHow {
            userBubble("どうやって教えればいい？")
            DataOnbBubble(text: "この3つのどれかで大丈夫。\nいちばん早いのは、写真フォルダから探すやり方だよ。")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            channelCards
                .transition(.opacity)
        }
        if beat >= .thanks, let c = state.picked.last {
            userBubble("「\(c.title)」で教える")
            DataOnbBubble(text: "ありがとう！覚えたことは、ふたりの記録にスタンプで残しておくね。")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            stampCard
                .padding(.leading, 40)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 64)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RenewalTokens.primaryFill, in: UnevenRoundedRectangle(
                    topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 4, topTrailingRadius: 18,
                    style: .continuous))
        }
        .padding(.top, 6)
    }

    private var channelCards: some View {
        VStack(spacing: 0) {
            ForEach(DataOnbChannel.allCases) { c in
                DataOnbChannelRow(channel: c, recommended: c == .fullBody, done: state.picked.contains(c)) {
                    state.pick(c)
                }
                if c != DataOnbChannel.allCases.last {
                    Divider().overlay(RenewalTokens.rule).padding(.leading, 68)
                }
            }
        }
        .partnerSoftCard(16)
        .padding(.leading, 40)
    }

    private var stampCard: some View {
        HStack(spacing: 12) {
            DataOnbStampRow(picked: state.picked, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("ふたりの記録")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Text("相棒画面でいつでも見られるよ")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .partnerSoftCard(16)
    }

    private var typingDots: some View {
        HStack(spacing: 8) {
            PartnerIconImage(size: 32)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(RenewalTokens.muted.opacity(0.5)).frame(width: 6, height: 6)
                        .phaseAnimator([0.3, 1]) { v, p in v.opacity(p) } animation: { _ in
                            .easeInOut(duration: 0.5).delay(Double(i) * 0.15)
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(RenewalTokens.surface, in: Capsule())
        }
        .accessibilityLabel("相棒が入力中")
    }

    // MARK: 返事のボタン

    private var replyBar: some View {
        VStack(spacing: 4) {
            switch beat {
            case .askWhy:
                replyChip("服を教えたらどうなるの？") { await say(.answerWhy, after: 0.8, then: .askHow) }
            case .askHow:
                replyChip("どうやって教えればいい？") { await say(.answerHow, after: 0.8) }
            case .answerHow:
                DataOnbLaterButton(title: "いまはやめておく") { state.finished = true }
            case .thanks:
                DataOnbPrimaryButton(title: "ホームで3案を見る") { state.finished = true }
            default:
                Color.clear.frame(height: 52)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(RenewalTokens.ground)
        .animation(.easeInOut(duration: 0.2), value: beat)
    }

    private func replyChip(_ text: String, action: @escaping () async -> Void) -> some View {
        Button {
            Haptic.impact(.soft)
            Task { await action() }
        } label: {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RenewalTokens.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RenewalTokens.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(RenewalTokens.ink, lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    /// 入力中の点を見せてから、次の発言を出す
    private func say(_ next: Beat, after seconds: Double, then follow: Beat? = nil) async {
        withAnimation { typing = true }
        try? await Task.sleep(for: .seconds(seconds))
        withAnimation(.spring(duration: 0.45)) {
            typing = false
            beat = next
        }
        if let follow {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation { beat = follow }
        }
    }
}

/// 想像 → 手持ち に変わっていく見本 (会話に出たときに一度だけ動く)
private struct DataOnbGrowingPreview: View {
    @State private var level = 0

    var body: some View {
        DataOnbOutfitPreview(level: level, compact: true)
            .task {
                for l in 1...2 {
                    try? await Task.sleep(for: .seconds(0.9))
                    withAnimation { level = l }
                }
            }
    }
}
