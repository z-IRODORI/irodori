//
//  LoadingDesignD.swift
//  irodori - Sandbox
//
//  案D: ミニゲーム「アイテムキャッチ」.
//  待ち時間に、落ちてくるファッションアイテムをタップしてキャッチする軽いゲーム。
//  TimelineView で毎フレーム位置を計算しているため、動いている最中でもタップ判定が正しく効く。
//

import SwiftUI

struct LoadingDesignD: View {
    private struct FallingItem: Identifiable {
        let id = UUID()
        let emoji: String
        let normalizedX: CGFloat      // 0...1
        let spawnTime: Date
        let fallDuration: TimeInterval
        let swaySeed: Double
    }

    @State private var items: [FallingItem] = []
    @State private var caughtCount = 0
    @State private var scoreBounce = false
    @State private var progress: CGFloat = 0

    private let emojis = ["👕", "👖", "🧢", "👗", "🧦", "👟", "👜", "🕶️"]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                LoadingDemoHeader(
                    title: "レビュー作成中...",
                    subtitle: "待ち時間にアイテムキャッチで遊ぼう！"
                )
                LoadingDemoProgressBar(progress: progress)
                    .padding(.horizontal, 48)
            }
            .padding(.top, 24)

            gameArea
                .padding(.horizontal, 20)

            scoreBoard
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .task { await runSpawnLoop() }
        .task { await runProgressLoop() }
    }

    // MARK: - ゲームエリア

    private var gameArea: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                ZStack {
                    ForEach(items) { item in
                        fallingItemView(item, now: context.date, size: geo.size)
                    }
                    basketView(size: geo.size)
                }
            }
        }
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func fallingItemView(_ item: FallingItem, now: Date, size: CGSize) -> some View {
        let t: Double = now.timeIntervalSince(item.spawnTime) / item.fallDuration
        if t >= 0, t <= 1.05 {
            let sway: CGFloat = CGFloat(sin(t * 4 * .pi + item.swaySeed)) * 14
            let x: CGFloat = item.normalizedX * (size.width - 60) + 30 + sway
            let y: CGFloat = CGFloat(t) * (size.height + 80) - 40
            Text(item.emoji)
                .font(.system(size: 38))
                .position(x: x, y: y)
                .onTapGesture { catchItem(item) }
        }
    }

    private func basketView(size: CGSize) -> some View {
        Text("🧺")
            .font(.system(size: 44))
            .scaleEffect(scoreBounce ? 1.25 : 1.0)
            .position(x: size.width / 2, y: size.height - 30)
            .allowsHitTesting(false)
    }

    private var scoreBoard: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("キャッチ \(caughtCount)")
                .font(.system(size: 15, weight: .bold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(LoadingSandbox.brandGradient)
        .clipShape(Capsule())
        .scaleEffect(scoreBounce ? 1.08 : 1.0)
    }

    // MARK: - ゲーム進行

    private func catchItem(_ item: FallingItem) {
        items.removeAll { $0.id == item.id }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            caughtCount += 1
            scoreBounce = true
        }
        Haptic.impact(.soft)
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                scoreBounce = false
            }
        }
    }

    private func runSpawnLoop() async {
        while !Task.isCancelled {
            let now = Date()
            items.append(
                FallingItem(
                    emoji: emojis.randomElement()!,
                    normalizedX: CGFloat.random(in: 0...1),
                    spawnTime: now,
                    fallDuration: TimeInterval.random(in: 3.0...4.5),
                    swaySeed: Double.random(in: 0...(2 * .pi))
                )
            )
            // 落ち切ったアイテムを掃除
            items.removeAll { now.timeIntervalSince($0.spawnTime) > $0.fallDuration + 0.5 }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 650...950)))
        }
    }

    private func runProgressLoop() async {
        while !Task.isCancelled {
            progress = 0
            withAnimation(.linear(duration: 10)) { progress = 1 }
            try? await Task.sleep(for: .seconds(10.6))
        }
    }
}

#Preview("D: ミニゲーム") {
    LoadingDesignD()
}
