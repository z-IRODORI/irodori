//
//  DataOnboardingDesignA.swift
//  irodori - Sandbox
//
//  案A「相棒の手帳」: 3枚のページで順に伝える。
//  1. 相棒の手帳には、まだ4つの答えしか書かれていない (空欄がある)
//  2. 服やコーデを教えると、3案が「想像」から「手持ち」に変わる
//  3. 教え方は3つ。教えた分だけ手帳に記録 (スタンプ) が増える
//

import SwiftUI

struct DataOnboardingDesignA: View {
    let state: DataOnbSandboxState
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                notebookPage.tag(0)
                previewPage.tag(1)
                channelsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: page)

            footer
        }
        .background(RenewalTokens.ground)
    }

    // MARK: 1. 手帳の空欄

    private var notebookPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                DataOnbBubble(text: "4つの答え、ちゃんと手帳に書いたよ。\nでも、まだ空欄がたくさんあるんだ。")
                notebook
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private var notebook: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("相棒の手帳")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RenewalTokens.ink)
                Spacer()
                Text("1ページ目")
                    .font(.system(size: 11))
                    .foregroundStyle(RenewalTokens.muted)
            }
            .padding(.bottom, 12)
            line("なりたい印象", value: "きれいめ", filled: true)
            line("大事にしたいこと", value: "着回しやすさ", filled: true)
            line("挑戦の幅", value: "少しだけ冒険", filled: true)
            line("話し方", value: "やさしく", filled: true)
            line("持っている服", value: nil, filled: false)
            line("よく着る色", value: nil, filled: false)
            line("最近のコーデ", value: nil, filled: false)
        }
        .padding(18)
        .background(
            // 罫線ノートの地 (うすいラベンダー)
            PartnerHue.lilac.wash.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(alignment: .leading) {
            // 綴じ目
            Rectangle().fill(PartnerHue.lilac.ink.opacity(0.18)).frame(width: 3).padding(.vertical, 18)
        }
    }

    private func line(_ label: String, value: String?, filled: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RenewalTokens.ink)
            } else {
                Text("まだ知らない")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PartnerHue.lilac.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(PartnerHue.lilac.ink.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            }
        }
        .frame(minHeight: 40)
        .overlay(alignment: .bottom) { Rectangle().fill(RenewalTokens.ink.opacity(0.06)).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    // MARK: 2. 3案の見えかた

    @State private var level = 0

    private var previewPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                DataOnbBubble(text: "服を見せてくれたら、\nあなたのクローゼットから3案を組めるようになるよ。")
                VStack(alignment: .leading, spacing: 14) {
                    Picker("相棒が知っていること", selection: $level) {
                        Text("いま").tag(0)
                        Text("服を5点").tag(1)
                        Text("コーデも").tag(2)
                    }
                    .pickerStyle(.segmented)
                    DataOnbOutfitPreview(level: level)
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundStyle(RenewalTokens.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: level)
                }
                .padding(16)
                .partnerSoftCard()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .task(id: page) {
            // このページを開いたら、いま → コーデも まで自動で見せる
            guard page == 1 else { return }
            level = 0
            for l in 1...2 {
                try? await Task.sleep(for: .seconds(1.4))
                guard page == 1 else { return }
                withAnimation { level = l }
            }
        }
    }

    private var caption: String {
        switch level {
        case 0: return "いまは答えから想像した服で組んでいます。買い足しの案が多めになります。"
        case 1: return "持っている服を混ぜて組めます。「これなら明日着られる」案が増えます。"
        default: return "着た日のコーデから、色の合わせ方や着回しのクセまで汲んで組みます。"
        }
    }

    // MARK: 3. 教え方と記録

    private var channelsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                DataOnbBubble(text: "教え方は3つ。\nどれからでも、ひとつで十分だよ。")
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
                .partnerSoftCard()

                // やんわり実績: 手帳の最後のページに押されるスタンプ
                HStack(spacing: 12) {
                    DataOnbStampRow(picked: state.picked, size: 32)
                    Text("教えてくれた日は、手帳にスタンプを残しておくね")
                        .font(.system(size: 12))
                        .foregroundStyle(RenewalTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    // MARK: 下部

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? RenewalTokens.ink : RenewalTokens.controlBorder)
                        .frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.3), value: page)
            .padding(.bottom, 12)
            .accessibilityHidden(true)

            if page < 2 {
                DataOnbPrimaryButton(title: "つぎへ") { page += 1 }
            } else if state.picked.isEmpty {
                DataOnbPrimaryButton(title: "写真フォルダから探す") { state.pick(.fullBody) }
            } else {
                DataOnbPrimaryButton(title: "ホームで3案を見る") { state.finished = true }
            }
            DataOnbLaterButton(title: page < 2 ? "スキップ" : "あとで教える") { state.finished = true }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(RenewalTokens.ground)
    }
}
