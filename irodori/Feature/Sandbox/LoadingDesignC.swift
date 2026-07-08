//
//  LoadingDesignC.swift
//  irodori - Sandbox
//
//  案C: 相棒トーク & 豆知識.
//  大きな相棒アイコンが呼吸しながら、タイプライター風の吹き出しで
//  進捗コメントとファッション豆知識を話し続ける。待ち時間の体感を会話で埋める案。
//

import SwiftUI

struct LoadingDesignC: View {
    @State private var visibleText = ""
    @State private var messageIndex = 0
    @State private var breathe = false
    @State private var progress: CGFloat = 0

    private let messages: [String] = [
        "いま君のコーデをじっくり見てるよ 👀",
        "豆知識: 白T × 黒パンツは王道モノトーン。小物の差し色が効くよ",
        "トップスとボトムスの切り抜きができたよ！いい感じ",
        "豆知識: ワイドパンツはトップスをインすると脚長効果◎",
        "もうすぐレビュー完成…たのしみにしてて！",
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            speechCard
                .padding(.horizontal, 32)

            buddy
                .padding(.top, 18)

            Spacer()

            VStack(spacing: 10) {
                LoadingDemoProgressBar(progress: progress)
                    .padding(.horizontal, 48)
                Text("レビュー作成中... (8〜10秒)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .task { await runProgressLoop() }
        .task(id: messageIndex) { await typeCurrentMessage() }
    }

    // MARK: - 吹き出し (タイプライター)

    private var speechCard: some View {
        VStack(spacing: -1) {
            HStack(alignment: .top, spacing: 0) {
                Text(visibleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                // タイプ中カーソル
                Text("|")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LoadingSandbox.brandPink)
                    .opacity(breathe ? 1 : 0.15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 66, alignment: .topLeading)
            .padding(16)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            LoadingDemoBubble.Triangle()
                .fill(Color.gray.opacity(0.08))
                .frame(width: 16, height: 9)
        }
    }

    // MARK: - 呼吸する相棒

    private var buddy: some View {
        ZStack {
            Circle()
                .fill(LoadingSandbox.brandGradient)
                .frame(width: 128, height: 128)
                .opacity(0.15)
                .scaleEffect(breathe ? 1.12 : 0.94)
            PartnerIconImage(size: 104)
                .overlay {
                    Circle().stroke(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                .scaleEffect(breathe ? 1.03 : 0.98)
                .rotationEffect(.degrees(breathe ? 2 : -2))
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(LoadingSandbox.brandPink)
                .opacity(breathe ? 1 : 0.3)
                .offset(x: 8, y: -4)
        }
    }

    // MARK: - 進行

    private func typeCurrentMessage() async {
        let message = messages[messageIndex]
        visibleText = ""
        for character in message {
            visibleText.append(character)
            try? await Task.sleep(for: .milliseconds(38))
            if Task.isCancelled { return }
        }
        try? await Task.sleep(for: .seconds(2.2))
        if Task.isCancelled { return }
        messageIndex = (messageIndex + 1) % messages.count
    }

    private func runProgressLoop() async {
        while !Task.isCancelled {
            progress = 0
            withAnimation(.linear(duration: 10)) { progress = 1 }
            try? await Task.sleep(for: .seconds(10.6))
        }
    }
}

#Preview("C: 相棒トーク") {
    LoadingDesignC()
}
